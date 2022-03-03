import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

task("hello")
  .addParam("greeting", "Say hello, be nice")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    console.log(taskArguments.greeting);
  });