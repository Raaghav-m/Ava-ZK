 
pragma solidity ^0.8.18;

import "./interfaces/ITeleporterMessenger.sol";

interface IGroth16Verifier {
    function verifyProof(
        uint[2] calldata _pA, 
        uint[2][2] calldata _pB, 
        uint[2] calldata _pC, 
        uint[1] calldata _pubSignals
    ) external view returns (bool);
}

contract ZKProofSender {
    ITeleporterMessenger public immutable teleporter;
    IGroth16Verifier public immutable verifier;
    
    
    // Events
    event ProofSent(
        bytes32 indexed destinationBlockchainID,
        address destinationAddress
    );
    
    constructor(address _teleporter, address _verifier) {
        teleporter = ITeleporterMessenger(_teleporter);
        verifier = IGroth16Verifier(_verifier);
    }
    
    function sendProof(
        bytes32 destinationBlockchainID,
        address destinationAddress,
        uint[2] calldata _pA,
        uint[2][2] calldata _pB, 
        uint[2] calldata _pC,
        uint[1] calldata _pubSignals
    ) external payable {
        require(destinationBlockchainID != bytes32(0), "Invalid destination");
        require(destinationAddress != address(0), "Invalid address");
        
        // Verify proof locally before sending
        require(verifier.verifyProof(_pA, _pB, _pC, _pubSignals), "Invalid proof");
            
        // Encode message
        bytes memory message = abi.encode(
            _pA,
            _pB,
            _pC,
            _pubSignals
        );
        
        // Send cross-chain message
        teleporter.sendCrossChainMessage(
            TeleporterMessageInput({
                destinationBlockchainID: destinationBlockchainID,
                destinationAddress: destinationAddress,
                feeInfo: TeleporterFeeInfo({feeTokenAddress: address(0), amount: 0}),
                requiredGasLimit: 500000,
                allowedRelayerAddresses: new address[](0),
                message: message
            })
        );
        
        emit ProofSent(destinationBlockchainID, destinationAddress);
    }
}