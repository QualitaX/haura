// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../Types.sol";

interface ISDCCall {
    function inceptTrade(address _withParty, string memory _tradeData, int _position, int256 _paymentAmount, string memory _initialSettlementData) external;
    function confirmTrade(address _withParty, string memory _tradeData, int _position, int256 _paymentAmount, string memory _initialSettlementData) external;
    function requestTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms) external;
    function confirmTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms) external;
    function cancelTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms) external;
    function requestReferenceRate(address _sdcContractAddress) external;
    function setURLs(string[] memory _urls, string memory _referenceRatePath) external;
    function withdrawLink() external;
    function getIRSReceipts() external view returns(Types.IRSReceipt[] memory);
}