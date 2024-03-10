from web3 import Web3


def EIP_1997(w3, proxy):
    """
    Access the implementation contract through the standard memory address used in EIP-1997

    Args:
    w3: Web3 connection instance.
    proxy: (string) proxy contract address

    Returns:
    (string) Implementation contract address (if exists, else 0x0)
    """
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

    return implementation_address


def OpenZeppelin(w3, proxy):
    """
    Access the implementation contract through the standard memory address used by OpenZeppelin pre EIP-1997.

    Args:
    w3: Web3 connection instance.
    proxy: (string) proxy contract address

    Returns:
    (string) Implementation contract address (if exists, else 0x0)
    """
    IMPLEMENTATION_SLOT = "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3"  # Standard memory address for storing implementation address

    implementation_address = Web3.to_hex(
        w3.eth.get_storage_at(
            proxy,
            IMPLEMENTATION_SLOT,
        )
    )

    implementation_address = hex(
        int(implementation_address, 16)
    )  # Remove leading zeroes

    return implementation_address
