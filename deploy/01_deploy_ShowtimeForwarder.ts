import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers} from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();

    console.log("Deploying ShowtimeForwarder from address:", namedAccounts.deployer);

    // const artifact = await hre.artifacts.readArtifact('ShowtimeForwarder');
    // console.log("Will be using the following deployment bytecode:", artifact.bytecode);

    const salt = ethers.utils.hexlify(4142695);
    const {address, deploy} = await deployments.deterministic(
        'ShowtimeForwarder',
        {
            from: namedAccounts.deployer,
            salt: salt
        }
    );

    console.log("It will be deployed at address:", address);

    try {
        const deployResult = await deploy();

        // console.log({deployResult})
        console.log("tx hash:", deployResult.transactionHash);
        console.log("ShowtimeForwarder deployed to:", deployResult.address);
    } catch (e: any) {
        const errorMessage = e.message;
        console.error({errorMessage});
    }
};

module.exports = func;