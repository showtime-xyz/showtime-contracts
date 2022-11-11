#!/usr/bin/env python3

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from warrant.aws_srp import AWSSRP
from web3.auto import w3

import boto3
import json
import requests
import time
import yaml

# from https://docs.openzeppelin.com/defender/api-auth
RELAYER_API_POOL_ID = 'us-west-2_iLmIggsiy'
RELAYER_API_CLIENT_ID = '1bpd19lcr33qvg5cr3oi79rdap'

boto3client = boto3.client('cognito-idp', region_name='us-west-2')

FORWARD_REQUEST_TYPE = 'ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 validUntilTime)'

@dataclass
class ForwarderConfig:
    domainSeparator: str
    address: str = "0x50c001c88b59dc3b833E0F062EfC2271CE88Cb89"    # deterministic deploy, so the address is the same on all chains
    requestTypeHash: str = w3.keccak(text=FORWARD_REQUEST_TYPE).hex() # 0xb91ae508e6f0e8e33913dec60d2fdcb39fe037ce56198c70a7927d7cd813fd96 on all chains


forwarderByNetwork = {
    # can be lifted from the emitted event in https://mumbai.polygonscan.com/tx/0xdd831c63c8f3893675d4080f2be4719aa4ff9f37995db099e12460762adea734#eventlog
    # or it could be computed as a somewhat complicated hash of EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
    'mumbai': ForwarderConfig(domainSeparator="0x5e5b00964aa6fad690fa48928347690e3f9a4ce056e98a45c10dd839e9aa77e7")
}


@dataclass
class Relayer:
    name: str
    API_KEY: str
    API_SECRET: str = field(repr=False)
    access_token: str = None

    # TODO: refresh the access token after it expires
    def generate_access_token(self):
        aws = AWSSRP(username=self.API_KEY,
                    password=self.API_SECRET,
                    pool_id=RELAYER_API_POOL_ID,
                    client_id=RELAYER_API_CLIENT_ID,
                    client=boto3client)
        tokens = aws.authenticate_user()
        self.access_token = tokens['AuthenticationResult']['AccessToken']
        print('Access Token:', self.access_token)


    def _generate_headers(self):
        return {
                "X-Api-Key": self.API_KEY,
                "Authorization": f"Bearer {self.access_token}",
                "Content-Type": "application/json"
            }


    def send_transaction(self, data):
        if self.access_token is None:
            self.generate_access_token()

        return requests.post("https://api.defender.openzeppelin.com/txs",
            headers=self._generate_headers(),
            data=data)


    def query_transaction(self, tx_id):
        if self.access_token is None:
            self.generate_access_token()

        return requests.get(f"https://api.defender.openzeppelin.com/txs/{tx_id}",
            headers=self._generate_headers())


@dataclass
class RelayerPool:
    relayers: list[Relayer] = field(default_factory=list)
    i: int = int(time.time())

    # round robin
    def _relayer(self):
        self.i += 1
        return self.relayers[self.i % len(self.relayers)]

    def send_transaction(self, data):
        relayer = self._relayer()
        return relayer, relayer.send_transaction(data)

    def query_transaction(self, tx_id):
        relayer = self._relayer()
        return relayer, relayer.query_transaction(tx_id)


def parse_relayer_config():
    relayers = []
    with open('relayers.yml') as f:
        relayer_config = yaml.safe_load(f)
        for relayer in relayer_config['mumbai']:
            relayers.append(Relayer(**relayer))
            print(relayers[-1])

    return relayers

def main():
    relayers = parse_relayer_config()
    pool = RelayerPool(relayers)

    # forwardRequest and signature are the output of scripts/sign_eip712.mjs
    forwardRequest = json.loads('''
{
  "from": "0xDE5E327cE4E7c1b64A757AaB8f2E699585977a34",
  "to": "0x50c001362FB06E2CB4D4e8138654267328a8B247",
  "value": 0,
  "gas": 1000000,
  "nonce": 1,
  "data": "0x331c143200000000000000000000000006b0d1875c4daee8a060e013e6ec996f19c0c7ed000000000000000000000000de5e327ce4e7c1b64a757aab8f2e699585977a34",
  "validUntilTime": 1650326099
}
    ''')

    signature = '0x64f8f28f42f0fa3b6d7e4db294f0cb475b8e676ac91a43ec4454960964fd0fa63386e7a89d2b11aff5774afab3889cce8c5a907dc11a3c76c949d0aebf9825681b'

    forwarderConfig = forwarderByNetwork['mumbai']

    # extracting the ABI for the execution function:
    # jq -c '.abi | map(select(.name == "execute"))' out/Forwarder.sol/Forwarder.json
    forwarderABI = [{"inputs":[{"components":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint256","name":"gas","type":"uint256"},{"internalType":"uint256","name":"nonce","type":"uint256"},{"internalType":"bytes","name":"data","type":"bytes"},{"internalType":"uint256","name":"validUntilTime","type":"uint256"}],"internalType":"struct IForwarder.ForwardRequest","name":"req","type":"tuple"},{"internalType":"bytes32","name":"domainSeparator","type":"bytes32"},{"internalType":"bytes32","name":"requestTypeHash","type":"bytes32"},{"internalType":"bytes","name":"suffixData","type":"bytes"},{"internalType":"bytes","name":"sig","type":"bytes"}],"name":"execute","outputs":[{"internalType":"bool","name":"success","type":"bool"},{"internalType":"bytes","name":"ret","type":"bytes"}],"stateMutability":"payable","type":"function"}]
    forwarder = w3.eth.contract(abi=forwarderABI, address=forwarderConfig.address)

    valid_until = datetime.utcnow() + timedelta(minutes=2)

    relayer_request = {
        'to': forwarder.address,
        'value': 0,
        'data': forwarder.encodeABI('execute', [
            [
                forwardRequest['from'],
                forwardRequest['to'],
                forwardRequest['value'],
                forwardRequest['gas'],
                forwardRequest['nonce'],
                forwardRequest['data'],
                forwardRequest['validUntilTime'],
            ],
            forwarderConfig.domainSeparator,
            forwarderConfig.requestTypeHash,
            "", # suffixData
            signature
        ]),
        'speed': 'safeLow',
        'gasLimit': 1100000,
        'validUntil': valid_until.replace(tzinfo=timezone.utc).isoformat(),
    }

    print('relayer_request =', relayer_request)

    relayer, response = pool.send_transaction(json.dumps(relayer_request))

    print('relayer_response =', response.json())
    transactionId = response.json()['transactionId']

    while True:
        response = relayer.query_transaction(transactionId)
        print(f"{relayer.name}\t{transactionId}\t{response.json()['hash']}\t{response.json()['status']}" )
        time.sleep(2)


if __name__ == '__main__':
    main()
