import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers} from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = 'OnePerAddressEditionMinter';

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();
    const forwarderAddress = (await deployments.get('ShowtimeForwarder')).address;

    console.log("Deploying " + contractName + " from address:", namedAccounts.deployer);

    // const artifact = await hre.artifacts.readArtifact(contractName);
    // console.log("Will be using the following deployment bytecode:",
    //     // we take the init code
    //     artifact.bytecode

    //     // and add the constructor arguments
    //     // (slice to remove the 0x prefix)
    //         + ethers.utils.hexZeroPad(forwarderAddress, 32).slice(2)
    // );

    const salt = ethers.utils.hexlify(29888296);
    const {address, deploy} = await deployments.deterministic(
        contractName,
        {
            from: namedAccounts.deployer,
            args: [
                forwarderAddress,
            ],
            salt: salt
        }
    );

    console.log("It will be deployed at address:", address);
    console.log("skipping " + contractName); return;

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