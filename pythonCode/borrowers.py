"""
Notes for future. 
Consider filtering by debt/borrow type relationship. That gives more control over what price movements are detrimental to the borrower.
"""

from web3 import AsyncHTTPProvider, AsyncWeb3, Web3
import requests
import Enums
import json
import asyncio
from utils import get_contract, from_ray, from_wad


# Create enums
Addresses = Enums.Addresses
APIs = Enums.APIs
Endpoints = Enums.Endpoints


def get_repayer_data(symbol, borrowers, earliest):
    """
    Query repays event emits.

    Params:
    symbol: (string) filter for borrows of this asset symbol.
    borrowers: list(str) addresses of borrowers who could have repayed their debt.
    earliest: (string) timestamp to begin collection of data from.

    Returns:
    (list): [ { user : { id: str }, amount : int , timestamp : int } ]
    """

    query = f"""
    {{
        repays(
            where: {{ reserve_: {{ symbol : "{symbol}" }} , user_in : {json.dumps(borrowers)} , timestamp_gt: {earliest} }}
            orderBy: timestamp
            orderDirection: desc
        ) {{
            user {{
            id
            }}
            amount
            timestamp
        }}
    }}
    """

    resp = requests.post(Endpoints.THE_GRAPH.AAVE_V3, json={"query": query})
    return resp.json()["data"]["repays"]


def get_borrower_data(symbol, first, skip=0):
    """
    Query borrower event emits.

    Params:
    symbol: (string) filter for borrows of this asset symbol.
    first: (int) number of entries to return.
    skip: (int) number of entries to skip before returning first.

    Returns:
    (list): [ { user : { id: str }, amount : int , timestamp : int } ]
    """

    query = f"""
    {{
        borrows(
            where: {{ reserve_ : {{ symbol : "{symbol}" }} }}
            orderBy: timestamp
            orderDirection: desc
            first: {first}
            skip: {skip}
        ) {{
            user {{
            id
            }}
            amount
            timestamp
        }}
    }}
    """

    resp = requests.post(Endpoints.THE_GRAPH.AAVE_V3, json={"query": query})
    return resp.json()["data"]["borrows"]


def get_earliest_time(data):
    """
    Get earliest timestamp from queried data. Assumes data is descending.

    Params:
    data: list of emitted events.

    Returns:
    (string) timestamp. same denomination as inputed.
    """

    return data[-1]["timestamp"]


def get_addresses(data):
    """
    Get 'address' elements from data. Not necessarily unique.

    Params:
    data: list of events.

    Returns:
    (list) list of address strings
    """

    # Map events to 'id' element.
    return list(map(lambda x: Web3.to_checksum_address(x["user"]["id"]), data))


def get_amounts(data):
    """
    Get 'amount' elements from data

    Params:
    data: list of events.

    Returns:
    (list) list of int 'amounts' in transaction
    """

    # Map events to 'amount' element.
    return list(map(lambda x: int(x["amount"]), data))


def in_debt(borrow_data, repay_data):
    """
    Filter the borrow events to keep only those with no record of full repayment.

    Params:
    borrow_data: list of borrow events
    repay_data: list of repay events

    Returns:
    (list) list of addresses with debt outstanding
    """

    # Create borrower record
    borrower_record = {k: 0 for k in get_addresses(borrow_data)}
    for k, v in zip(get_addresses(borrow_data), get_amounts(borrow_data)):
        borrower_record[k] += v
    # Create repayment record
    repayer_record = {k: 0 for k in get_addresses(repay_data)}
    for k, v in zip(get_addresses(repay_data), get_amounts(repay_data)):
        repayer_record[k] += v
    # Remove borrowers who repayed
    for k, v in zip(get_addresses(repay_data), get_amounts(repay_data)):
        borrower_record[k] -= v

    have_debt = filter(
        lambda k: borrower_record[k] > 0, borrower_record.keys()
    )  # Filter for addresses who are in debt.

    return list(have_debt)


def get_targets(symbol, first, skip=0):
    """
    Filter the first number of accounts with debt

    Params:
    symbol: (string) asset pool to filter on
    first: (int) number of entries to return.
    skip: (int) number of entries to skip before returning first.

    Returns:
    (list) list of strings of addresses

    """
    borrow_data = get_borrower_data(symbol, first, skip)

    earliest_time = get_earliest_time(borrow_data)

    borrower_addresses = get_addresses(borrow_data)

    repay_data = get_repayer_data(symbol, borrower_addresses, earliest_time)

    return in_debt(borrow_data, repay_data)  # Filter for accounts who are in debt


async def get_accounts_data(proxy, addresses):
    """
    Get the accounts data of these Aave users.

    Parameters:
    proxy: (contract) an Aave pool proxy contract instance
    addresses: list of address strings

    Returns:
    (list) A list of user account details.
    """

    accounts_info = await asyncio.gather(
        *[proxy.functions.getUserAccountData(address).call() for address in addresses]
    )  # Preserves order of async calls

    # Convert units
    for account in accounts_info:
        account[0] = account[0] / 1e8  # Total collateral, in USD
        account[1] = account[1] / 1e8  # Total debt, in USD
        account[2] = account[2] / 1e8  # Borrowing power, in USD
        account[3] = account[3] / 1e4  # Decimal form, average liquidation threshold
        account[4] = account[4] / 1e4  # Decimal form, average maximum loan to value
        account[5] = from_wad(account[5])  # Health metric

    return accounts_info


async def main():
    """
    Test calculating targets from GraphQL endpoint and getting their status from Aave smart contract.
    """

    global w3

    w3 = AsyncWeb3(AsyncHTTPProvider(Endpoints.INFURA))

    targets = get_targets("WETH", 10)  # Get most recent borrowers with debt

    print(targets)

    # Get Aave pool proxy contract.
    proxy_contract = await get_contract(w3, Addresses.Aave.Mainnet.POOL_PROXY)

    target_data = await get_accounts_data(
        proxy_contract, targets
    )  # Get details about specific borrowers from Aave

    print(target_data)


if __name__ == "__main__":

    # Test run
    asyncio.run(main())
