// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./interfaces/ITeleporterReceiver.sol";
import "./interfaces/ITeleporterMessenger.sol";

interface IGroth16Verifier {
    function verifyProof(
        uint[2] calldata _pA, 
        uint[2][2] calldata _pB, 
        uint[2] calldata _pC, 
        uint[1] calldata _pubSignals
    ) external view returns (bool);
}

contract ZKProofReceiver is ITeleporterReceiver {
    ITeleporterMessenger public immutable teleporter;
    IGroth16Verifier public immutable verifier;
    bool public isProofValid;

    // Struct to hold the latest proof data
    struct ProofData {
        uint[2] pA;
        uint[2][2] pB;
        uint[2] pC;
        uint[1] pubSignals;
    }

    ProofData latestProof; // Removed 'public' to avoid getter issue

    // Events       
    event ProofReceived(
        bytes32 indexed sourceBlockchainID,
        address indexed originSenderAddress,
        bool verified
    );

    event ProofVerificationSuccess(
        uint256 publicSignal
    );

    event ProofVerificationFailed(
        bytes32 indexed sourceBlockchainID,
        address indexed originSenderAddress,
        string reason
    );

    // Errors
    error InvalidProof();

    constructor(address _teleporter, address _verifier) {
        teleporter = ITeleporterMessenger(_teleporter);
        verifier = IGroth16Verifier(_verifier);
    }

    function receiveTeleporterMessage(
    bytes32 sourceBlockchainID,
    address originSenderAddress, // added back to match interface
    bytes calldata message
) external override {
    require(msg.sender == address(teleporter), "Only Teleporter can deliver messages");

    (
        uint[2] memory _pA,
        uint[2][2] memory _pB,
        uint[2] memory _pC,
        uint[1] memory _pubSignals
    ) = abi.decode(message, (uint[2], uint[2][2], uint[2], uint[1]));

    // Store the proof
    latestProof = ProofData({
        pA: _pA,
        pB: _pB,
        pC: _pC,
        pubSignals: _pubSignals
    });

    // Verify the proof
    bool isValid = verifier.verifyProof(_pA, _pB, _pC, _pubSignals);

    if (isValid) {
        emit ProofReceived(sourceBlockchainID, originSenderAddress, true);
        emit ProofVerificationSuccess( _pubSignals[0]);
    } else {
        emit ProofReceived(sourceBlockchainID, originSenderAddress, false);
        emit ProofVerificationFailed(sourceBlockchainID, originSenderAddress, "Invalid proof");
    }
}


    function verifyProofDirectly(
    uint[2] memory _pA,
    uint[2][2] memory _pB,
    uint[2] memory _pC,
    uint[1] memory _pubSignals
) public returns (bool) {
    isProofValid = verifier.verifyProof(_pA, _pB, _pC, _pubSignals);
    require(isProofValid, "NOT VERIFIED");

    if (isProofValid) {
        emit ProofVerificationSuccess(_pubSignals[0]);
    }
    return isProofValid;
}

    function verifyStoredProof() external returns (bool) {
        // Copy storage arrays to memory to match calldata type
        uint[2] memory pA = latestProof.pA;
        uint[2][2] memory pB = latestProof.pB;
        uint[2] memory pC = latestProof.pC;
        uint[1] memory pubSignals = latestProof.pubSignals;

        return verifyProofDirectly(pA, pB, pC, pubSignals);
    }

    // Getter function for latestProof
    function getLatestProof() external view returns (
        uint[2] memory pA,
        uint[2][2] memory pB,
        uint[2] memory pC,
        uint[1] memory pubSignals
    ) {
        return (
            latestProof.pA,
            latestProof.pB,
            latestProof.pC,
            latestProof.pubSignals
        );
    }
}
