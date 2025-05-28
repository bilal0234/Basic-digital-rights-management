// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    
    // Struct to represent digital content
    struct DigitalContent {
        uint256 id;
        string title;
        string contentHash; // IPFS hash or similar
        address owner;
        uint256 price;
        uint256 totalLicenses;
        uint256 licensesIssued;
        bool isActive;
        uint256 createdAt;
    }
    
    // Struct to represent a license
    struct License {
        uint256 contentId;
        address licensee;
        uint256 expiryDate;
        bool isActive;
        uint256 issuedAt;
    }
    
    // State variables
    mapping(uint256 => DigitalContent) public digitalContents;
    mapping(address => mapping(uint256 => License)) public userLicenses;
    mapping(uint256 => address[]) public contentLicensees;
    
    uint256 public nextContentId = 1;
    uint256 public constant LICENSE_DURATION = 365 days; // 1 year license
    
    // Events
    event ContentRegistered(uint256 indexed contentId, address indexed owner, string title);
    event LicensePurchased(uint256 indexed contentId, address indexed licensee, uint256 expiryDate);
    event LicenseRevoked(uint256 indexed contentId, address indexed licensee);
    
    // Modifiers
    modifier onlyContentOwner(uint256 _contentId) {
        require(digitalContents[_contentId].owner == msg.sender, "Not the content owner");
        _;
    }
    
    modifier contentExists(uint256 _contentId) {
        require(digitalContents[_contentId].id != 0, "Content does not exist");
        _;
    }
    
    modifier validLicense(uint256 _contentId) {
        License memory license = userLicenses[msg.sender][_contentId];
        require(license.isActive && block.timestamp <= license.expiryDate, "Invalid or expired license");
        _;
    }
    
    /**
     * @dev Register new digital content for rights management
     * @param _title Title of the digital content
     * @param _contentHash Hash of the content (IPFS hash)
     * @param _price Price per license in wei
     * @param _totalLicenses Maximum number of licenses that can be issued
     */
    function registerContent(
        string memory _title,
        string memory _contentHash,
        uint256 _price,
        uint256 _totalLicenses
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");
        require(_price > 0, "Price must be greater than 0");
        require(_totalLicenses > 0, "Total licenses must be greater than 0");
        
        uint256 contentId = nextContentId++;
        
        digitalContents[contentId] = DigitalContent({
            id: contentId,
            title: _title,
            contentHash: _contentHash,
            owner: msg.sender,
            price: _price,
            totalLicenses: _totalLicenses,
            licensesIssued: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        emit ContentRegistered(contentId, msg.sender, _title);
        return contentId;
    }
    
    /**
     * @dev Purchase a license for digital content
     * @param _contentId ID of the content to license
     */
    function purchaseLicense(uint256 _contentId) external payable contentExists(_contentId) {
        DigitalContent storage content = digitalContents[_contentId];
        
        require(content.isActive, "Content is not active");
        require(content.licensesIssued < content.totalLicenses, "No more licenses available");
        require(msg.value >= content.price, "Insufficient payment");
        require(!userLicenses[msg.sender][_contentId].isActive, "License already exists");
        
        // Calculate expiry date
        uint256 expiryDate = block.timestamp + LICENSE_DURATION;
        
        // Create license for user
        userLicenses[msg.sender][_contentId] = License({
            contentId: _contentId,
            licensee: msg.sender,
            expiryDate: expiryDate,
            isActive: true,
            issuedAt: block.timestamp
        });
        
        // Add to content licensees list
        contentLicensees[_contentId].push(msg.sender);
        
        // Update content stats
        content.licensesIssued++;
        
        // Transfer payment to content owner
        payable(content.owner).transfer(content.price);
        
        // Refund excess payment
        if (msg.value > content.price) {
            payable(msg.sender).transfer(msg.value - content.price);
        }
        
        emit LicensePurchased(_contentId, msg.sender, expiryDate);
    }
    
    /**
     * @dev Verify if a user has valid license for content
     * @param _user Address of the user to check
     * @param _contentId ID of the content
     * @return bool indicating if user has valid license
     */
    function verifyLicense(address _user, uint256 _contentId) 
        external 
        view 
        contentExists(_contentId) 
        returns (bool) 
    {
        License memory license = userLicenses[_user][_contentId];
        return license.isActive && block.timestamp <= license.expiryDate;
    }
    
    // Additional utility functions
    
    /**
     * @dev Get content details
     */
    function getContentDetails(uint256 _contentId) 
        external 
        view 
        contentExists(_contentId) 
        returns (
            string memory title,
            string memory contentHash,
            address owner,
            uint256 price,
            uint256 totalLicenses,
            uint256 licensesIssued,
            bool isActive
        ) 
    {
        DigitalContent memory content = digitalContents[_contentId];
        return (
            content.title,
            content.contentHash,
            content.owner,
            content.price,
            content.totalLicenses,
            content.licensesIssued,
            content.isActive
        );
    }
    
    /**
     * @dev Get user's license details for specific content
     */
    function getUserLicense(address _user, uint256 _contentId) 
        external 
        view 
        returns (
            uint256 expiryDate,
            bool isActive,
            uint256 issuedAt
        ) 
    {
        License memory license = userLicenses[_user][_contentId];
        return (license.expiryDate, license.isActive, license.issuedAt);
    }
    
    /**
     * @dev Deactivate content (only owner)
     */
    function deactivateContent(uint256 _contentId) 
        external 
        onlyContentOwner(_contentId) 
        contentExists(_contentId) 
    {
        digitalContents[_contentId].isActive = false;
    }
    
    /**
     * @dev Get all licensees for a content
     */
    function getContentLicensees(uint256 _contentId) 
        external 
        view 
        contentExists(_contentId) 
        returns (address[] memory) 
    {
        return contentLicensees[_contentId];
    }
}
