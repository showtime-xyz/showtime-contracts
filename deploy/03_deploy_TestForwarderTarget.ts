import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = 'TestForwarderTarget';
    console.log("skipping " + contractName); return;

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();
    const forwarderAddress = (await deployments.get('ShowtimeForwarder')).address;

    console.log("Deploying " + contractName + " from address:", namedAccounts.deployer);
    console.log({forwarderAddress});

    const {address, deploy} = await deployments.deterministic(
        contractName,
        {
            from: namedAccounts.deployer,
            args: [ forwarderAddress]
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