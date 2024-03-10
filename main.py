from web3 import Web3, AsyncHTTPProvider, AsyncWeb3
import requests
from proxy_patterns import EIP_1997, OpenZeppelin
import Enums
import asyncio
import time

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

    time.sleep(0.25)  # Blocking sleep to obey 5 cps rate limit

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


def from_ray(val):
    """
    Convert from ray units. A ray is a int representing a floating point with 27 decimal points of precision

    Args:
    val: (int) value in ray units.

    Returns:
    (int) Value in standard units.
    """

    return val / 1e27


async def get_token_contracts(addresses):
    """
    Return token contracts at given addresses

    Args:
    addresses: (list[string]) List of string addresses of tokens

    Return:
    (list[contracts]) List of token contract objects
    """
    token_contracts = await asyncio.gather(*[get_contract(a) for a in addresses])

    return token_contracts


async def get_token_names(contracts):
    """
    Get token names from token contracts.

    Args:
    contracts: (list[contracts]) List of token contracts

    Returns:
    list(strings) List of string names of tokens
    """

    token_names = await asyncio.gather(
        *[contract.functions.name().call() for contract in contracts]
    )

    return token_names


async def get_tokens_rates(proxy, addresses):
    """
    Returns borrow and yield rates (%) for Aave tokens.

    Args:
    proxy: (contract) Aave pool proxy contract instance
    addresses: ([string]) List of token addresses

    Returns:
    ([{str : int, str : int}]) List of dictionaries containing lend and borrow rates.
    """

    token_info = await asyncio.gather(
        *[proxy.functions.getReserveData(address).call() for address in addresses]
    )  # Preserves order of async calls

    token_rates = map(
        lambda info: {
            "lend_rate": from_ray(info[2]) * 100,
            "borrow_rate": from_ray(info[4]) * 100,
        },
        token_info,
    )

    return list(token_rates)


async def main():

    global w3

    w3 = AsyncWeb3(AsyncHTTPProvider(Endpoints.INFURA))

    # Get proxy contract.
    proxy_contract = await get_contract(Addresses.Aave.Mainnet.POOL_PROXY)

    token_addresses = (
        await proxy_contract.functions.getReservesList().call()
    )  # Get token addresses

    token_contracts = await get_token_contracts(token_addresses)

    token_names = await get_token_names(token_contracts)

    token_rates = await get_tokens_rates(proxy_contract, token_addresses)

    rate_dict = {k: v for k, v in zip(token_names, token_rates)}

    print(rate_dict)


if __name__ == "__main__":

    asyncio.run(main())
