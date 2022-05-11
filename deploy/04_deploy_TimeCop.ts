import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers} from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const contractName = 'TimeCop';

    const deployments = hre.deployments;
    const namedAccounts = await hre.getNamedAccounts();
    const _maxDurationSeconds = 31 * 24 * 3600; // 31 days

    console.log("\n\n### " + contractName + " ###");
    console.log("from:", namedAccounts.deployer);
    const artifact = await hre.artifacts.readArtifact(contractName);
    console.log("deployment bytecode:",
        // we take the init code
        artifact.bytecode.slice(2)

        // and add the constructor arguments
        // (slice to remove the 0x prefix)
        + ethers.utils.hexZeroPad(ethers.utils.hexlify(_maxDurationSeconds), 32).slice(2)
    );

    const salt = ethers.utils.hexlify(427679);
    const {address, deploy} = await deployments.deterministic(
        contractName,
        {
            from: namedAccounts.deployer,
            args: [_maxDurationSeconds],
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