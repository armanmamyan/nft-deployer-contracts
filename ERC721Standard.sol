// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTContract is ERC721A, ReentrancyGuard, Ownable(msg.sender) {
    event SetMaximumAllowedTokens(uint256 _count);
    event SetMaximumSupply(uint256 _count);
    event SetMaximumAllowedTokensPerWallet(uint256 _count);
    event SetPrice(uint256 _price);
    event SetBaseUri(string baseURI);
    event Mint(address userAddress, uint256 _count);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;
    Counters.Counter private _nextTokenId;

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

    constructor(string memory baseURI) ERC721("NFT Contract", "NFTC") {
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

    function tokensMinted() public view returns (uint256) {
        return _tokenSupply.current();
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
        uint256 i;

        for (i = 0; i < reserveAtATime; i++) {
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
            reservedCount++;
        }
    }

    function adminAirdrop(
        address _walletAddress,
        uint256 _count
    ) public onlyOwner saleIsOpen {
        uint256 supply = _tokenSupply.current();

        require(supply + _count <= MAX_SUPPLY, "Total supply exceeded.");

        for (uint256 i = 0; i < _count; i++) {
            _tokenSupply.increment();
            _safeMint(_walletAddress, _tokenSupply.current());
        }
    }

    function batchAirdropToMultipleAddresses(
        uint256 _count,
        address[] calldata addresses
    ) external saleIsOpen onlyOwner {
        uint256 supply = _tokenSupply.current();

        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add a null address");
            require(supply + _count <= MAX_SUPPLY, "Total supply exceeded.");
            for (uint256 j = 0; j < _count; j++) {
                _tokenSupply.increment();
                _safeMint(addresses[i], _tokenSupply.current());
            }
        }
    }

    function mint(
        uint256 _count
    ) public payable saleIsOpen mintCompliance(_count) {
        require(
            balanceOf(msg.sender) + _count <= maxAllowedTokensPerWallet,
            "Max holding cap reached."
        );
        require(
            tx.origin == msg.sender,
            "Calling from other contract is not allowed."
        );

        uint256 mintIndex = _tokenSupply.current();

        if (msg.sender != owner()) {
            require(isActive, "Sale is not active currently.");
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

        for (uint256 i = 0; i < _count; i++) {
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
        emit Mint(msg.sender, _count);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }
}
