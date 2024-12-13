// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../Types.sol";

interface ISDCCall {
    function inceptTrade(address _withParty, string memory _tradeData, int _position, int256 _paymentAmount, string memory _initialSettlementData) external;
    function confirmTrade(address _withParty, string memory _tradeData, int _position, int256 _paymentAmount, string memory _initialSettlementData) external;
    function performSettlement(int256 _settlementAmount, string memory _settlementData) external;
    function requestTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms) external;
    function confirmTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms) external;
    function cancelTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms) external;
    function requestReferenceRate(address _sdcContractAddress) external;
    function setURLs(string[] memory _urls, string memory _referenceRatePath) external;
    function withdrawLink() external;
    function getTradeState() external view returns(TradeState);
    function getTradeID() external view returns(string memory);
    function getInceptingTime() external view returns(uint256);
    function getConfirmationTime() external view returns(uint256);
    function getInitialMargin() external view returns(uint256);
    function getInitialTerminationFee() external view returns(uint256);
    function getMarginCall(address _account) external view returns(uint256);
    function getMarginRequirement(address _account) external view returns(Types.MarginRequirement memory);
    function getRateMultiplier() external view returns(uint256);
    function getIRSReceipts() external view returns(Types.IRSReceipt[] memory);
    function getURLs() external view returns(string[] memory);
}