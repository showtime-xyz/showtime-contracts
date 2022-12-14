import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = "GatedEditionCreator";

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();
    const minterAddress = (await deployments.get("GatedEditionMinter")).address;
    const timeCopAddress = (await deployments.get("TimeCop")).address;
    // see https://github.com/ourzora/nft-editions#where-is-the-factory-contract-deployed=
    const editionCreatorAddress = {
        hardhat: "0x773E5B82179E6CE1CdF8c5C0d736e797b3ceDDDC",
        mumbai: "0x773E5B82179E6CE1CdF8c5C0d736e797b3ceDDDC",
        polygon: "0x4500590AfC7f12575d613457aF01F06b1eEE57a3",
    }[hre.network.name];

    if (!editionCreatorAddress) {
        throw new Error(`${hre.network.name} is not supported`);
    }

    console.log("\n\n### " + contractName + " ###");
    console.log("from:", namedAccounts.deployer);
    const artifact = await hre.artifacts.readArtifact(contractName);
    console.log(
        "deployment bytecode:",
        // we take the init code
        artifact.bytecode.slice(2) +
            // and add the constructor arguments
            // (slice to remove the 0x prefix)
            ethers.utils.hexZeroPad(editionCreatorAddress, 32).slice(2) +
            ethers.utils.hexZeroPad(minterAddress, 32).slice(2) +
            ethers.utils.hexZeroPad(timeCopAddress, 32).slice(2)
    );

    // results in address 0x50C001482BBc5C9720F11DB34AE49b89b7494BBA on polygon
    const salt = "0x00000000000000000000000000000000000000000000000c00000000001bd413";
    const { address, deploy } = await deployments.deterministic(contractName, {
        from: namedAccounts.deployer,
        args: [editionCreatorAddress, minterAddress, timeCopAddress],
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
