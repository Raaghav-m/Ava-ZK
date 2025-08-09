pragma solidity 0.8.18;
 
struct TeleporterMessageInput {
    bytes32 destinationBlockchainID;
    address destinationAddress;
    TeleporterFeeInfo feeInfo;
    uint256 requiredGasLimit;
    address[] allowedRelayerAddresses;
    bytes message;
}
 
struct TeleporterFeeInfo {
    address feeTokenAddress;
    uint256 amount;
}
struct TeleporterMessage {
    uint256 messageNonce;
    address originSenderAddress;
    bytes32 destinationBlockchainID;
    address destinationAddress;
    uint256 requiredGasLimit;
    address[] allowedRelayerAddresses;
    TeleporterMessageReceipt[] receipts;
    bytes message;
}
struct TeleporterMessageReceipt {
    uint256 receivedMessageNonce;
    address relayerRewardAddress;
}

 
/**
 * @dev Interface that describes functionalities for a cross chain messenger.
 */
interface ITeleporterMessenger {
    /**
     * @dev Emitted when sending a interchain message cross chain.
     */
 	event SendCrossChainMessage(
        uint256 indexed messageID,
        bytes32 indexed destinationBlockchainID,
        TeleporterMessage message,
        TeleporterFeeInfo feeInfo
    );
 
    /**
     * @dev Called by transactions to initiate the sending of a cross L1 message.
     */
	function sendCrossChainMessage(TeleporterMessageInput calldata messageInput)
        external
        returns (uint256);
 
}