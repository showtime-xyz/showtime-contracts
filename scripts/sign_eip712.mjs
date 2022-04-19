import {ethers} from "ethers";

const forwarderABI = ["function getNonce(address from) view returns(uint256)"];
const editionCreatorABI = ["function createEdition(string memory _name, string memory _symbol, string memory _description, string memory _animationUrl, bytes32 _animationHash, string memory _imageUrl, bytes32 _imageHash, uint256 _editionSize, uint256 _royaltyBPS, address minter) returns(uint256)"];
const minterABI = ["function mintEdition(address collection, address _to)"];

const USER_ADDRESS = "0xDE5E327cE4E7c1b64A757AaB8f2E699585977a34";
const USER_PRIVATE_KEY = "0xbfea5ee5076b0bff4a26f7e3b5a8b8093c664a330cb7ab024f041b9ae077fa2e";

const ShowtimeForwarderContract = new ethers.Contract(
    "0x50c001c88b59dc3b833E0F062EfC2271CE88Cb89",
    forwarderABI);

const NETWORKS = {
    foundry: {
        chainId: 99,
        forwarder: {
            address: "0xCe71065D4017F316EC606Fe4422e11eB2c47c246",
            getNonce: async () => {
                return 0;
            }
        },
        testForwarderTargetAddress: "0x185a4dc360CE69bDCceE33b3784B0282f7961aea",
    },

    mumbai: {
        chainId: 80001,
        forwarder: ShowtimeForwarderContract.connect(new ethers.providers.JsonRpcProvider("https://rpc-mumbai.matic.today")),
        metaSingleEditionMintableCreator: "0x50c001c0aaa97B06De431432FDbF275e1F349694",
        onePerAddressMinterContract: "0x50c001362FB06E2CB4D4e8138654267328a8B247",
        testForwarderTargetAddress: "0x7Fb382B775e2aA82Ee8fd523EffDc3807E7fa09C",
    },

    polygon: {
        chainId: 137,
        // forwarder: ShowtimeForwarderContract.connect(new ethers.providers.JsonRpcProvider("https://polygon-rpc.com")),
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                              CREATE DROP                                                           //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// let targetAddress = network.metaSingleEditionMintableCreator;
// let targetInterface = new ethers.utils.Interface(editionCreatorABI);

// let callData = targetInterface.encodeFunctionData("createEdition", [
//     "Hello Drop",
//     "DROP",
//     "A drop of love",
//     "", // animationUrl
//     "0x0000000000000000000000000000000000000000000000000000000000000000", // animationHash
//     "ipfs://QmNSh7w75EPALBQC57tZiMggy7atTxD3sgmfmEtsi2CjCG", // imageUrl
//     "0x5a10c03724f18ec2534436cc5f5d4e9d60a91c2c6cea3ad7e623eb3d54e20ea9", // imageHash
//     100, // editionSize
//     1000, // royaltyBPS
//     network.onePerAddressMinterContract, // minter
// ]);



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                              CLAIM DROP                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

let targetAddress = network.onePerAddressMinterContract;
let targetInterface = new ethers.utils.Interface(minterABI);

let callData = targetInterface.encodeFunctionData("mintEdition", [
    "0x06b0d1875C4DaEE8a060e013e6Ec996F19C0C7ed", // collection
    USER_ADDRESS, // to
]);

// The data to sign
const value = {
    from: USER_ADDRESS,
    to: targetAddress,
    value: 0,

    // we can hardcode a sufficiently high value for now
    gas: 1000000,

    // this is the one remote call we need to make before signing
    nonce: (await network.forwarder.getNonce(USER_ADDRESS)).toNumber(),
    data: callData,
    validUntilTime: Math.floor((new Date()).getTime() / 1000) + 5 * 60, // now + 5 min
};

console.log('Signing data for domain:');
console.log({domain});
console.log('With the following ForwardRequest:');
console.log(JSON.stringify(value, null, 2));

// the provider does not actually matter, this is a local operation
const signer = new ethers.Wallet(USER_PRIVATE_KEY, ethers.getDefaultProvider('mainnet'));
const signature = await signer._signTypedData(domain, types, value);
console.log({signature});
