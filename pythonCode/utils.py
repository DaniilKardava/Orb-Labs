from proxy_patterns import EIP_1997, OpenZeppelin
from web3 import Web3
import time
import asyncio
import requests
import Enums

# Create enums
Addresses = Enums.Addresses
APIs = Enums.APIs
Endpoints = Enums.Endpoints


async def get_implementation_address(w3, proxy):
    """
    Return the implementation address of a proxy contract.

    Parameters:
    w3: web3 connections instance.
    proxy: (string) Proxy address.

    Returns:
    (address) address of the implementation contract
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


async def get_abi(url_endpoint):
    """
    Get contract abi.

    Parameters:
    API string endpoint

    Returns:
    List of dictionaries containing contract method signatures.
    """

    time.sleep(0.25)  # Blocking sleep to obey 5 cps rate limit

    response = await asyncio.to_thread(requests.get, url_endpoint)

    return response.json()["result"]


async def get_contract(w3, address):
    """
    Returns contract instance.

    Parameters:
    w3: web3 connection instance
    address: (string) Hex contract address

    Returns:
    w3.eth.contract instance
    """

    abi_address = await get_implementation_address(w3, address)
    abi = await get_abi(Endpoints.ETHERSCAN.ABI(abi_address))

    return w3.eth.contract(address, abi=abi)


def from_ray(val):
    """
    Convert from ray units. A ray is a int representing a floating point with 27 decimal points of precision

    Parameters:
    val: (int) value in ray units.

    Returns:
    (int) Value in standard units.
    """

    return val / 1e27


def from_wad(val):
    """
    Convert from wad units. A wad is a int representing a floating point with 18 decimal points of precision

    Parameters:
    val: (int) value in wad units.

    Returns:
    (int) Value in standard units.
    """

    return val / 1e18
