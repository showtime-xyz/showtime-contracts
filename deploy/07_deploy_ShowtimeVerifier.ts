import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = 'ShowtimeVerifier';
    console.log("skipping " + contractName); return;

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();

    console.log("\n\n### " + contractName + " ###");
    console.log("from:", namedAccounts.deployer);

    const {address, deploy} = await deployments.deterministic(
        contractName,
        {
            from: namedAccounts.deployer,
            args: [
                namedAccounts.deployer // _owner
            ]
        }
    );

    console.log("It will be deployed at address:", address);

    try {
        const deployResult = await deploy();

        // console.log({deployResult})
        console.log("tx hash:", deployResult.transactionHash);
        console.log("deployed to:", deployResult.address);
    } catch (e: any) {
        const errorMessage = e.message;
        console.error({errorMessage});
    }
};

module.exports = func;
