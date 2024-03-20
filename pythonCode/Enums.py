from web3 import Web3


# Addresses Enum
class Addresses:

    PERSONAL = Web3.to_checksum_address("0x3B3C3f31DAe1FD6d056f67fB2D0ea2FD3217AD67")

    class Aave:

        class Mainnet:

            POOL_PROXY = Web3.to_checksum_address(
                "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2"
            )


# API Keys Enum
class APIs:

    INFURA = "6ad6c314a07247839facdd2943580991"  # Node provider

    ETHERSCAN = "WHV2VBD8YJZCNJEBI65QZ7QQKBESDKH89F"  # API key for ABI requests


# URL Enum
class Endpoints:

    INFURA = f"https://mainnet.infura.io/v3/{APIs.INFURA}"  # Infura node provider

    class ETHERSCAN:

        ABI = (
            lambda a: f"https://api.etherscan.io/api?module=contract&action=getabi&address={a}&apikey={APIs.ETHERSCAN}"
        )  # Get url endpoint for abi specification on etherscan

    class THE_GRAPH:

        AAVE_V3 = "https://api.thegraph.com/subgraphs/name/aave/protocol-v3"
