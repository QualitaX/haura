// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../Types.sol";
import "../ERC6123.sol";

contract SDCFactory {
    uint256 numberOfContracts;
    mapping(uint256 => address) irsContracts;

    function deploySDCContract(
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        address _linkToken,
        address _chainlinkOracle,
        string memory _jobId,
        uint256 _initialMarginBuffer,
        uint256 _initialTerminationFee,
        uint256 _rateMultiplier 
    ) external returns(uint256) {
        require(
            msg.sender == _irs.fixedRatePayer || msg.sender == _irs.floatingRatePayer,
            "INVALID CALLER"
        );

        ERC6123 irs = new ERC6123{salt: bytes32(abi.encodePacked(
            _irs.fixedRatePayer, _irs.floatingRatePayer, block.timestamp
        ))}(
            _irsTokenName,
            _irsTokenSymbol,
            _irs,
            _linkToken,
            _chainlinkOracle,
            _jobId,
            _initialMarginBuffer,
            _initialTerminationFee,
            _rateMultiplier 
        );

        uint256 id = numberOfContracts;

        irsContracts[numberOfContracts] = address(irs);
        numberOfContracts = id + 1;

        return id;
    }

    function getIRSContract(uint256 _id) external view returns(address) {
        return irsContracts[_id];
    }

    function getNumberOfContracts() external view returns(uint256) {
        return numberOfContracts;
    }
}