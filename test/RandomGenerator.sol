// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

contract RandomGenerator {
    function randomAddress(uint256 salt) public pure returns (address) {
        uint256 val = uint256(keccak256(abi.encodePacked(salt)));
        return address(uint160(val));
    }

    function randomUint(uint256 salt) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(salt)));
    }
}
