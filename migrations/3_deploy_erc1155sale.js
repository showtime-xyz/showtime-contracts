const MT = artifacts.require("ShowtimeMT");
const ERC1155Sale = artifacts.require("ERC1155Sale");

const MUMBAI_FORWARDER = "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b";
const POLYGON_FORWARDER = "0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8";

module.exports = async function (deployer, network) {
    const mt = await MT.new();
    const sale = await ERC1155Sale.new(mt.address, []);
    if (network === "mumbai_testnet") {
        await sale.setTrustedForwarder(MUMBAI_FORWARDER);
    } else if (network === "matic_mainnet") {
        await sale.setTrustedForwarder(POLYGON_FORWARDER);
    }
    console.log({
        mt: mt.address,
        sale: sale.address,
    });
};
