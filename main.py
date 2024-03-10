from web3 import Web3, AsyncHTTPProvider, AsyncWeb3
import requests
from proxy_patterns import EIP_1997, OpenZeppelin
import Enums
import asyncio

# Create enums
Addresses = Enums.Addresses
APIs = Enums.APIs
Endpoints = Enums.Endpoints


async def get_implementation_address(proxy) -> str:
    """
    Return the implementation address of a proxy contract.

    Args:
    proxy: (string) Proxy address.
    """

    implementation_address = await EIP_1997(w3, proxy)  # Try EIP standard

    if implementation_address == "0x0":
        implementation_address = await OpenZeppelin(
            w3, proxy
        )  # Try OpenZeppelin standard

    if implementation_address == "0x0":
        return proxy

    implementation_address = Web3.to_checksum_address(implementation_address)

    return implementation_address


async def get_abi(url_endpoint) -> list[dict]:
    """
    Args:
    API string endpoint

    Returns:
    List of dictionaries containing contract method signatures.
    """

    response = await asyncio.to_thread(requests.get, url_endpoint)

    return response.json()["result"]


async def get_contract(address):
    """
    Returns contract instance.

    Args:
    address: (string) Hex contract address

    Returns:
    w3.eth.contract instance
    """

    abi_address = await get_implementation_address(address)
    abi = await get_abi(Endpoints.ETHERSCAN.ABI(abi_address))

    return w3.eth.contract(address, abi=abi)


async def main():

    global w3

    w3 = AsyncWeb3(AsyncHTTPProvider(Endpoints.INFURA))

    # Get proxy contract.
    proxy_contract = await get_contract(Addresses.Aave.Mainnet.POOL_PROXY)

    # Print tokens
    tokens = await proxy_contract.functions.getReservesList().call()

    print(tokens)

    token_contracts = await asyncio.gather(*[get_contract(a) for a in tokens])
    token_names = await asyncio.gather(
        *[contract.functions.name().call() for contract in token_contracts]
    )
    print(token_names)


if __name__ == "__main__":

    asyncio.run(main())
