// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// NAP-EX — Evidence Registry
/// يختم جذر Merkle لسلسلة حفظ كل بلاغ — إثبات وجود غير قابل للتلاعب
contract EvidenceRegistry {
    struct Anchor {
        bytes32 root;
        uint256 timestamp;
        address anchoredBy;
    }

    mapping(string => Anchor) public roots;
    string[] public batchIds;

    event Anchored(string indexed batchId, bytes32 indexed merkleRoot, uint256 timestamp);

    function anchor(string calldata batchId, bytes32 merkleRoot) external {
        require(roots[batchId].timestamp == 0, "batch already anchored");
        roots[batchId] = Anchor(merkleRoot, block.timestamp, msg.sender);
        batchIds.push(batchId);
        emit Anchored(batchId, merkleRoot, block.timestamp);
    }

    function verify(string calldata batchId, bytes32 expectedRoot)
        external
        view
        returns (bool)
    {
        return roots[batchId].root == expectedRoot && roots[batchId].timestamp != 0;
    }

    function totalBatches() external view returns (uint256) {
        return batchIds.length;
    }
}
