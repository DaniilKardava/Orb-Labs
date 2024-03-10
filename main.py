from web3 import Web3
import requests


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
            lambda adrs: f"https://api.etherscan.io/api?module=contract&action=getabi&address={adrs}&apikey={APIs.ETHERSCAN}"
        )  # Contract ABI


def get_implementation_address(proxy) -> str:
    """
    Return the implementation address of a proxy contract.

    Args:
    proxy: (string) Proxy address.
    """

    # EIP-1967 Transparent Proxy Pattern
    IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"  # Standard memory address for storing implementation address

    implementation_address = Web3.to_hex(
        w3.eth.get_storage_at(
            proxy,
            IMPLEMENTATION_SLOT,
        )
    )

    implementation_address = hex(
        int(implementation_address, 16)
    )  # Remove leading zeroes

    # OpenZeppelin's Unstructured Storage Pattern
    if implementation_address == "0x0":

        abi = get_abi(Endpoints.ETHERSCAN.ABI(proxy))  # Get proxy abi
        contract = w3.eth.contract(proxy, abi=abi)  # Get proxy contract

        print(abi)
        print(contract.address)

        try:
            implementation_address = contract.functions.implementation().call()
        except Exception as e:
            print(e)
            return proxy

    implementation_address = Web3.to_checksum_address(implementation_address)

    return implementation_address


def get_abi(url_endpoint) -> list[dict]:
    """
    Args:
    API string endpoint

    Returns:
    List of dictionaries containing contract method signatures.
    """

    return requests.get(url_endpoint).json()["result"]


def get_contract(address):
    """
    Returns contract instance.

    Args:
    address: (string) Hex contract address

    Returns:
    w3.eth.contract instance
    """

    print(address)
    abi_address = get_implementation_address(address)
    print(abi_address)
    return w3.eth.contract(address, abi=get_abi(Endpoints.ETHERSCAN.ABI(abi_address)))


def main():

    global w3

    w3 = Web3(Web3.HTTPProvider(Endpoints.INFURA))

    # Get proxy contract.
    proxy_contract = get_contract(Addresses.Aave.Mainnet.POOL_PROXY)

    # Print reserves
    reserves = proxy_contract.functions.getReservesList().call()
    names = list(
        map(
            lambda a: get_contract(a).functions.name().call(),
            reserves,
        )
    )
    print(names)


if __name__ == "__main__":

    main()
