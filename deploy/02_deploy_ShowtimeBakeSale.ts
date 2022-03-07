import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers} from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployments = hre.deployments;
    const ShowtimeMT = await deployments.get('ShowtimeMT');
    const ShowtimeV1Market = await deployments.get('ShowtimeV1Market');
    const namedAccounts = await hre.getNamedAccounts();

    console.log("Deploying from address:", namedAccounts.deployer);

    // FIXME: I hardcoded the gas price to avoid the weird "transaction underpriced" error on mumbai

    // the following will only deploy "ShowtimeBakeSale" if the contract was never deployed
    // or if the code changed since last deployment
    try {
        const deployResult = await deployments.deploy(
            'ShowtimeBakeSale',
            {
                from: namedAccounts.deployer,
                // maxFeePerGas: ethers.BigNumber.from(30 * 10 ** 9), // 30 gwei
                // maxPriorityFeePerGas: ethers.BigNumber.from(30 * 10 ** 9), // 30 gwei
                gasPrice: ethers.BigNumber.from(35 * 10 ** 9), // 35 gwei
                gasLimit: 6000000,
                args: [
                    ShowtimeMT.address,
                    ShowtimeV1Market.address,
                    [namedAccounts.ukraineDAO],
                    [100],
                ],
            }
        );

        // console.log({deployResult})
        console.log("tx hash:", deployResult.transactionHash);
        console.log("ShowtimeBakeSale deployed to:", deployResult.address);
    } catch (e: any) {
        const errorMessage = e.message;
        console.error({errorMessage});
    }
};

module.exports = func;