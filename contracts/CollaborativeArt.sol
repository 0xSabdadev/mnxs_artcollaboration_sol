// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// base project : init (starter)
contract CollaborativeArt{
    address public owner;
    struct Artist{
        address artistAddress;
        uint256 ownershipPercentage;
    }
    Artist[] public artists;

    mapping(address => uint256) public artistToOwnershipPercentage;
    mapping(address => bool) public isArtist;
    uint256 public totalPercentage = 0;
    uint256 public artworkPrice;

    event ArtworkSold(uint256 price, string message);
    event DisputeResolved(string message);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier onlyArtist() {
        require(isArtist[msg.sender], "Only an artist can call this function");
        _;
    }

    constructor(){
        owner = msg.sender;
    }

    // base function add
    function addArtist(address _artistAddress, uint256 _ownershipPercentage) public onlyOwner{
        require(totalPercentage + _ownershipPercentage <=100,"Total Ownership max 100%");
        Artist memory newArtist = Artist(_artistAddress, _ownershipPercentage);
        artists.push(newArtist);
        artistToOwnershipPercentage[_artistAddress] = _ownershipPercentage;
        isArtist[_artistAddress] = true;
        totalPercentage += _ownershipPercentage;
    }

    // base function artwork price
    function setArtworkPrice(uint256 _price) public onlyOwner{
        artworkPrice = _price;
    }

    // base function purchase
    function purchaseArtwork() public payable{
        require(msg.value == artworkPrice, "Payment must equal to art price");
        distributeFunds();
        emit ArtworkSold(artworkPrice, "artwork sold");
    }

    // base func pay
    function distributeFunds() private{
        for (uint256 i = 0; i < artists.length; i++){
            Artist memory artist = artists[i];
            payable(artist.artistAddress).transfer((artworkPrice * artist.ownershipPercentage )/100);
        }
    }

    // base func dispute
    function resolveDispute(string memory _message) public view onlyOwner returns (string memory) {
        return _message;
    }
}