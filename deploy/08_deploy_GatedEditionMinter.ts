import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = "GatedEditionMinter";

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();
    const verifierAddress = (await deployments.get("ShowtimeVerifier")).address;
    const timeCopAddress = (await deployments.get("TimeCop")).address;

    console.log("\n\n### " + contractName + " ###");
    console.log("from:", namedAccounts.deployer);
    const artifact = await hre.artifacts.readArtifact(contractName);
    console.log(
        "deployment bytecode:",
        // we take the init code
        artifact.bytecode.slice(2) +
            // and add the constructor arguments
            // (slice to remove the 0x prefix)
            ethers.utils.hexZeroPad(verifierAddress, 32).slice(2) +
            ethers.utils.hexZeroPad(timeCopAddress, 32).slice(2)
    );

    const salt = ethers.utils.hexlify(3229371);
    const { address, deploy } = await deployments.deterministic(contractName, {
        from: namedAccounts.deployer,
        args: [verifierAddress, timeCopAddress],
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
    } catch (e: any) {
        const errorMessage = e.message;
        console.error({ errorMessage });
    }
};

module.exports = func;
