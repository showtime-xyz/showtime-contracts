import {ethers} from "ethers";

const forwarderABI = ["function getNonce(address from) view returns(uint256)"];

const USER_ADDRESS = "0xDE5E327cE4E7c1b64A757AaB8f2E699585977a34";
const USER_PRIVATE_KEY = "0xbfea5ee5076b0bff4a26f7e3b5a8b8093c664a330cb7ab024f041b9ae077fa2e";

const ShowtimeForwarderContract = new ethers.Contract(
    "0x50c001c88b59dc3b833E0F062EfC2271CE88Cb89",
    forwarderABI);

const NETWORKS = {
    foundry: {
        chainId: 99,
        forwarder: {
            address: "0xce71065d4017f316ec606fe4422e11eb2c47c246",
            getNonce: async () => {
                return 0;
            }
        }
    },

    mumbai: {
        chainId: 80001,
        forwarder: ShowtimeForwarderContract.connect(new ethers.providers.JsonRpcProvider("https://rpc-mumbai.matic.today")),
    },

    polygon: {
        chainId: 137,
        forwarder: ShowtimeForwarderContract.connect(new ethers.providers.JsonRpcProvider("https://polygon-rpc.com")),
    },
}

var network;

try {
    const networkIndex = process.argv.findIndex(x => x === '--network');
    if (networkIndex === -1) {
        throw new Error("No --network specified");
    }

    const networkName = process.argv[networkIndex + 1];
    network = NETWORKS[networkName];
    if (!network) {
        throw new Error("Invalid network: " + networkName);
    }
} catch (e) {
    console.log("Usage: node {} --network <foundry|mumbai|polygon>".replace("{}", process.argv[1]));
    console.log({e});
    process.exit(1);
}

const domain = {
    name: 'showtime.io',
    version: '1',
    chainId: network.chainId,
    verifyingContract: network.forwarder.address,
};

// The named list of all type definitions
const types = {
    ForwardRequest: [
        { name: 'from', type: 'address' },
        { name: 'to', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'gas', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'data', type: 'bytes' },
        { name: 'validUntilTime', type: 'uint256' },
    ]
};

// these values depend on the contract we are trying to call
let targetAddress = '0x185a4dc360CE69bDCceE33b3784B0282f7961aea';
let targetInterface = new ethers.utils.Interface([
        "function emitMessage(string memory message)"
    ]);
let callData = targetInterface.encodeFunctionData("emitMessage", ["hello"]);

// The data to sign
const value = {
    from: USER_ADDRESS,
    to: targetAddress,
    value: 0,

    // we can hardcode a sufficiently high value for now
    gas: 10000,

    // this is the one remote call we need to make before signing
    nonce: await network.forwarder.getNonce(USER_ADDRESS),
    data: callData,
    validUntilTime: 7697467249,
};

console.log('Signing data for domain:');
console.log({domain});
console.log('With the following ForwardRequest:');
console.log({value});

// the provider does not actually matter, this is a local operation
const signer = new ethers.Wallet(USER_PRIVATE_KEY, ethers.getDefaultProvider('mainnet'));
const signature = await signer._signTypedData(domain, types, value);
console.log({signature});
