// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../Types.sol";
import "../ERC6123.sol";

contract SDCFactory {
    event SDCContractDeployed(
        string swapID,
        address sdcContractAddress,
        uint256 timestamp
    );

    function deploySDCContract(
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        address _linkToken,
        address _chainlinkOracle,
        string memory _jobId,
        uint256 _initialMarginBuffer,
        uint256 _initialTerminationFee,
        uint256 _rateMultiplier,
        string memory _swapID
    ) external {
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
            _rateMultiplier,
            _swapID 
        );

        emit SDCContractDeployed(
            _swapID,
            address(irs),
            block.timestamp
        );
    }
}