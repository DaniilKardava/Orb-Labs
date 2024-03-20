from web3 import AsyncHTTPProvider, AsyncWeb3
import Enums
import asyncio
from utils import get_contract, from_ray

# Create enums
Addresses = Enums.Addresses
APIs = Enums.APIs
Endpoints = Enums.Endpoints


async def get_token_contracts(addresses):
    """
    Return token contracts at given addresses

    Parameters:
    addresses: (list[string]) List of string addresses of tokens

    Return:
    (list[contracts]) List of token contract objects
    """
    token_contracts = await asyncio.gather(*[get_contract(w3, a) for a in addresses])

    return token_contracts


async def get_token_names(contracts):
    """
    Get token names from token contracts.

    Parameters:
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

    Parameters:
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
    proxy_contract = await get_contract(w3, Addresses.Aave.Mainnet.POOL_PROXY)

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
