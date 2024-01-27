// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTContract is ERC721A, ReentrancyGuard, Ownable(msg.sender) {
    event SetMaximumAllowedTokens(uint256 _count);
    event SetMaximumSupply(uint256 _count);
    event SetMaximumAllowedTokensPerWallet(uint256 _count);
    event SetMaxTokenForPresale(uint256 _count);
    event SetRoot(bytes32 _root);
    event SetPrice(uint256 _price);
    event SetPresalePrice(uint256 _price);
    event SetBaseUri(string baseURI);
    event Mint(address userAddress, uint256 _count);

    uint256 public mintPrice = 0.15 ether;
    uint256 public presalePrice = 0.1 ether;

    uint256 private reserveAtATime = 1;
    uint256 private reservedCount = 0;
    uint256 private maxReserveCount = 100;

    string _baseTokenURI;

    bool public isActive = false;
    bool public isPresaleActive = false;

    uint256 public MAX_SUPPLY = 10000;
    uint256 public maxAllowedTokensPerPurchase = 1;
    uint256 public maxAllowedTokensPerWallet = 5;
    uint256 public presaleWalletLimitation = 2;

    mapping(address => bool) private _allowList;
    mapping(address => uint256) private _allowListClaimed;

    constructor(string memory baseURI) ERC721A("NFT Contract", "NFTC") {
        setBaseURI(baseURI);
    }

    modifier saleIsOpen() {
        require(totalSupply() < MAX_SUPPLY, "Sale has ended.");
        _;
    }

    modifier mintCompliance(uint256 _mintAmount) {
        require(
            tx.origin == msg.sender,
            "Calling from other contract is not allowed."
        );
        require(
            _mintAmount > 0 &&
                numberMinted(msg.sender) + _mintAmount <=
                maxAllowedTokensPerWallet,
            "Invalid mint amount or minted max amount already."
        );
        _;
    }

    modifier presaleMintCompliance(uint256 _mintAmount) {
        require(
            tx.origin == msg.sender,
            "Calling from other contract is not allowed."
        );
        require(_allowList[addr], "Your are not whitelisted");
        require(
            _mintAmount > 0 &&
                numberMinted(msg.sender) + _mintAmount <=
                presaleWalletLimitation,
            "Invalid mint amount or minted max amount already."
        );
        _;
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function setMaximumAllowedTokens(uint256 _count) public onlyOwner {
        maxAllowedTokensPerPurchase = _count;
        emit SetMaximumAllowedTokens(_count);
    }

    function setMaxAllowedTokensPerWallet(uint256 _count) public onlyOwner {
        maxAllowedTokensPerWallet = _count;
        emit SetMaximumAllowedTokensPerWallet(_count);
    }

    function togglePublicSale() public onlyOwner {
        isActive = !isActive;
    }

    function setMaxMintSupply(uint256 maxMintSupply) external onlyOwner {
        MAX_SUPPLY = maxMintSupply;
        emit SetMaximumSupply(maxMintSupply);
    }

    function setReserveAtATime(uint256 val) public onlyOwner {
        reserveAtATime = val;
    }

    function setMaxReserve(uint256 val) public onlyOwner {
        maxReserveCount = val;
    }

    function setPrice(uint256 _price) public onlyOwner {
        mintPrice = _price;
        emit SetPrice(_price);
    }

    function togglePresaleActive() external onlyOwner {
        isPresaleActive = !isPresaleActive;
    }

    function setPresaleWalletLimitation(uint256 maxMint) external onlyOwner {
        presaleWalletLimitation = maxMint;
        emit SetMaxTokenForPresale(maxMint);
    }

    function setPresalePrice(uint256 _presalePrice) public onlyOwner {
        presalePrice = _presalePrice;
        emit SetPresalePrice(_presalePrice);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
        emit SetBaseUri(baseURI);
    }

    function getReserveAtATime() external view returns (uint256) {
        return reserveAtATime;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function reserveNft() public onlyOwner {
        require(
            reservedCount <= maxReserveCount,
            "Max Reserves taken already!"
        );
        reservedCount += reserveAtATime;
        _safeMint(msg.sender, reserveAtATime);
    }

    function adminAirdrop(
        uint256 _count,
        address _address
    ) external onlyOwner saleIsOpen {
        uint256 supply = totalSupply();

        require(supply + _count <= MAX_SUPPLY, "Total supply exceeded.");
        _safeMint(_address, _count);
    }

    function batchAirdropToMultipleAddresses(
        uint256 _count,
        address[] calldata addresses
    ) external onlyOwner saleIsOpen {
        uint256 supply = totalSupply();

        for (uint256 i = 0; i < addresses.length; i++) {
            require(supply + _count <= MAX_SUPPLY, "Total supply exceeded.");
            require(addresses[i] != address(0), "Can't add a null address");
            _safeMint(addresses[i], _count);
        }
    }

    function addToWhiteList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add a null address");
            _allowList[addresses[i]] = true;
            _allowListClaimed[addresses[i]] > 0
                ? _allowListClaimed[addresses[i]]
                : 0;
        }
    }

    function removeFromWhiteList(
        address[] calldata addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add a null address");
            _allowList[addresses[i]] = false;
        }
    }

    function allowListClaimedBy(address owner) external view returns (uint256) {
        require(owner != address(0), "Zero address not on Allow List");
        return _allowListClaimed[owner];
    }

    function mint(
        uint256 _count
    ) public payable mintCompliance(_count) saleIsOpen {
        uint256 mintIndex = totalSupply();

        if (msg.sender != owner()) {
            require(isActive, "Sale is not active currently.");
            require(
                balanceOf(msg.sender) + _count <= maxAllowedTokensPerWallet,
                "Max holding cap reached."
            );
        }

        require(mintIndex + _count <= MAX_SUPPLY, "Total supply exceeded.");
        require(
            _count <= maxAllowedTokensPerPurchase,
            "Exceeds maximum allowed tokens"
        );

        require(
            msg.value >= mintPrice * _count,
            "Insufficient ETH amount sent."
        );

        _safeMint(msg.sender, _count);
        emit Mint(msg.sender, _count);
    }

    function preSaleMint(
        uint256 _count
    ) public payable presaleMintCompliance(_count) saleIsOpen {
        uint256 mintIndex = totalSupply();

        require(isPresaleActive, "Presale is not active");
        require(_allowList[msg.sender], "You are not on the White List");

        require(mintIndex + _count <= MAX_SUPPLY, "Total supply exceeded.");
        require(
            msg.value >= presalePrice * _count,
            "Insuffient ETH amount sent."
        );

        _safeMint(msg.sender, _count);
        emit Mint(msg.sender, _count);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }
}