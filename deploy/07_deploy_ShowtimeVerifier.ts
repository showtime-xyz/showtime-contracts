import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = "ShowtimeVerifier";
    console.log("skipping " + contractName);
    return;

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();

    console.log("\n\n### " + contractName + " ###");
    console.log("from:", namedAccounts.deployer);

    const { address, deploy } = await deployments.deterministic(contractName, {
        from: namedAccounts.deployer,
        args: [
            namedAccounts.deployer, // _owner
        ],
    });

    console.log("It will be deployed at address:", address);

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
        if (currentManager === ethers.constants.AddressZero) {
            let manager = "0x904Fe53cd90999559d2f97A108B550507305D556"; // mumbai config
            console.log("setting manager to:", manager);
            let txResult = await verifier.setManager(manager);
            console.log({ txResult });
        }

        let demoSigner = "0x8801C427F0a3120C36653BCC570e999646446f5F";
        let demoSignerValidity = await verifier.signerValidity(demoSigner);
        console.log({ demoSignerValidity });
        if (demoSignerValidity.eq(0)) {
            console.log("registering demo signer:", demoSigner);
            let txResult = await verifier.registerSigner(demoSigner, 7 /* days */);
            console.log({ txResult });
        }
    } catch (e: any) {
        const errorMessage = e.message;
        console.error({ errorMessage });
    }
};

module.exports = func;
