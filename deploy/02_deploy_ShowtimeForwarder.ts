import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers} from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = 'ShowtimeForwarder';

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();

    console.log("Deploying " + contractName + " from address:", namedAccounts.deployer);

    // const artifact = await hre.artifacts.readArtifact(contractName);
    // console.log("Will be using the following deployment bytecode:", artifact.bytecode);

    // with the default deterministic deployment proxy (0x4e59b44847b379578588920cA78FbF26c0B4956C)
    // and the bytecode at commit 3aa1bf9e, this salt gives us a nice address (0x50c001c88b59dc3b833E0F062EfC2271CE88Cb89)
    const salt = ethers.utils.hexlify(4142695);
    const {address, deploy} = await deployments.deterministic(
        contractName,
        {
            from: namedAccounts.deployer,
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