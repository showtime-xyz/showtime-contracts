import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = "ShowtimeVerifier";

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();

    console.log("\n\n### " + contractName + " ###");
    console.log("from:", namedAccounts.deployer);

    const artifact = await hre.artifacts.readArtifact(contractName);
    console.log(
        "deployment bytecode:",
        // we take the init code
        artifact.bytecode.slice(2) +
            // and add the constructor arguments
            // (slice to remove the 0x prefix)
            ethers.utils.hexZeroPad(namedAccounts.deployer, 32).slice(2)
    );

    // deploys to 0x50C0017836517dc49C9EBC7615d8B322A0f91F67
    const salt = "0x0000000000000000000000000000000000000000000000130000000000130710";
    ethers.utils.hexlify;
    const { address, deploy } = await deployments.deterministic(contractName, {
        from: namedAccounts.deployer,
        args: [
            namedAccounts.deployer, // _owner
        ],
        salt: salt,
    });

    console.log("It will be deployed at address:", address);

    console.log("skipping " + contractName);
    return;

    try {
        const deployResult = await deploy();

        // console.log({deployResult})
        console.log("tx hash:", deployResult.transactionHash);
        console.log("deployed to:", deployResult.address);

        // configure the deployed instance
        const account = await ethers.getSigner(namedAccounts.deployer);
        let verifier = new ethers.Contract(deployResult.address, deployResult.abi, account);

        let currentManager = await verifier.manager();
        console.log({ currentManager });
        if (currentManager === ethers.constants.AddressZero && hre.network.name === "mumbai") {
            let manager = "0x904Fe53cd90999559d2f97A108B550507305D556"; // mumbai-relayer-1
            console.log("setting manager to:", manager);
            let txResult = await verifier.setManager(manager);
            console.log({ txResult });
        }

        let demoSigner = "0x8801C427F0a3120C36653BCC570e999646446f5F";
        let demoSignerValidity = await verifier.signerValidity(demoSigner);
        console.log({ demoSignerValidity });
        if (demoSignerValidity.eq(0)) {
            console.log("registering demo signer:", demoSigner);
            let txResult = await verifier.registerSigner(demoSigner, 1 /* days */);
            console.log({ txResult });
        }

        if (hre.network.name === "polygon") {
            let executionMultisig = "0x8C929a803A5Aae8B0F8fB9df0217332cBD7C6cB5";
            console.log("transferring ownership to multisig:", executionMultisig);
            let txResult = await verifier.transferOwnership(executionMultisig);
        }
    } catch (e: any) {
        const errorMessage = e.message;
        console.error({ errorMessage });
    }
};

module.exports = func;
