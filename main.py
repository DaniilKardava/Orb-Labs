from web3 import Web3
import requests
from proxy_patterns import EIP_1997, OpenZeppelin
import Enums

# Create enums
Addresses = Enums.Addresses
APIs = Enums.APIs
Endpoints = Enums.Endpoints


def get_implementation_address(proxy) -> str:
    """
    Return the implementation address of a proxy contract.

    Args:
    proxy: (string) Proxy address.
    """

    implementation_address = EIP_1997(w3, proxy)  # Try EIP standard

    if implementation_address == "0x0":
        implementation_address = OpenZeppelin(w3, proxy)  # Try OpenZeppelin standard

    if implementation_address == "0x0":
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

    abi_address = get_implementation_address(address)

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
