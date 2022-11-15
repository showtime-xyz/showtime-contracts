from dataclasses import dataclass

@dataclass
class ChainConfig:
    chainId: int
    name: str
    rpcUrl: str
    verifierAddress: str


mumbai = ChainConfig(
    chainId=80001,
    name="mumbai",
    rpcUrl="https://matic-mumbai.chainstacklabs.com",
    # formerly "0xE5eC1D79E0AF57C57AAeE8D64cDCDf52493b8711"
    verifierAddress="0x50C0017836517dc49C9EBC7615d8B322A0f91F67")

polygon = ChainConfig(
    chainId=137,
    name="polygon",
    rpcUrl="https://polygon-rpc.com",
    verifierAddress="0x50C0017836517dc49C9EBC7615d8B322A0f91F67")
