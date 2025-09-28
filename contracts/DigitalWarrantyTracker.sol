// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract DigitalWarrantyTracker {
    address public admin;

    struct Product {
        address owner;
        string serial;
        uint256 purchaseDate;
        uint256 warrantyExpiry;
        bool claimPending;
    }

    mapping(uint256 => Product) public products;
    mapping(uint256 => bool) public productExists;

    event ProductRegistered(uint256 productId, address indexed owner, string serial, uint256 purchaseDate, uint256 warrantyExpiry);
    event ClaimFiled(uint256 productId, address indexed claimant, uint256 filedAt);
    event ClaimApproved(uint256 productId, address indexed approver, uint256 approvedAt);
    event ClaimRejected(uint256 productId, address indexed approver, uint256 rejectedAt, string reason);
    event WarrantyExtended(uint256 productId, uint256 oldExpiry, uint256 newExpiry);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyOwner(uint256 productId) {
        require(productExists[productId], "Product not found");
        require(products[productId].owner == msg.sender, "Not product owner");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerProduct(
        uint256 productId,
        address to,
        string calldata serial,
        uint256 warrantySeconds
    ) external onlyAdmin {
        require(!productExists[productId], "Product already exists");
        require(to != address(0), "Invalid owner");

        uint256 nowTs = block.timestamp;
        uint256 expiry = nowTs + warrantySeconds;

        products[productId] = Product({
            owner: to,
            serial: serial,
            purchaseDate: nowTs,
            warrantyExpiry: expiry,
            claimPending: false
        });
        productExists[productId] = true;

        emit ProductRegistered(productId, to, serial, nowTs, expiry);
    }

    function extendWarranty(uint256 productId, uint256 extraSeconds) external onlyAdmin {
        require(productExists[productId], "Product not found");
        uint256 oldExpiry = products[productId].warrantyExpiry;
        uint256 newExpiry = oldExpiry + extraSeconds;
        products[productId].warrantyExpiry = newExpiry;

        emit WarrantyExtended(productId, oldExpiry, newExpiry);
    }

    function approveClaim(uint256 productId) external onlyAdmin {
        require(productExists[productId], "Product not found");
        require(products[productId].claimPending, "No claim pending");

        products[productId].claimPending = false;
        emit ClaimApproved(productId, msg.sender, block.timestamp);
    }

    function rejectClaim(uint256 productId, string calldata reason) external onlyAdmin {
        require(productExists[productId], "Product not found");
        require(products[productId].claimPending, "No claim pending");

        products[productId].claimPending = false;
        emit ClaimRejected(productId, msg.sender, block.timestamp, reason);
    }

    function fileClaim(uint256 productId) external onlyOwner(productId) {
        require(block.timestamp <= products[productId].warrantyExpiry, "Warranty expired");
        require(!products[productId].claimPending, "Claim already pending");

        products[productId].claimPending = true;
        emit ClaimFiled(productId, msg.sender, block.timestamp);
    }

    function isWarrantyActive(uint256 productId) external view returns (bool) {
        require(productExists[productId], "Product not found");
        return block.timestamp <= products[productId].warrantyExpiry;
    }

    function getProduct(uint256 productId) external view returns (
        address owner,
        string memory serial,
        uint256 purchaseDate,
        uint256 warrantyExpiry,
        bool claimPending
    ) {
        require(productExists[productId], "Product not found");
        Product memory p = products[productId];
        return (p.owner, p.serial, p.purchaseDate, p.warrantyExpiry, p.claimPending);
    }
}
