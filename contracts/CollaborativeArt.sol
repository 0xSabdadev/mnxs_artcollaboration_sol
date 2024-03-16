// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

// project : develop
contract CollaborativeArt is EIP712{
    using ECDSA for bytes32;

    struct Artist{
        address artistAddress;
        uint256 ownershipPercentage;
    }
    struct Milestone{
        string description;
        uint256 deadline;
        bool completed;
    }

    address public owner;
    Artist[] public artists;
    Milestone[] public milestones;

    mapping(address => uint256) public artistToOwnershipPercentage;
    mapping(address => bool) public artistSigned;
    uint256 public totalPercentage = 0;
    uint256 public artworkPrice;

    event MilestoneCompleted(uint256 milestoneIndex,string description);
    event ArtworkSold(uint256 price, string message);
    event DisputeResolved(string message);
    event ArtistSigned(address artist);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier onlyArtist() {
        require(artistSigned[msg.sender], "Only an artist can call this function");
        _;
    }

    constructor() EIP712("CollaborativeArt","1.0"){
        owner = msg.sender;
    }

    // base function add
    function addArtist(address _artistAddress, uint256 _ownershipPercentage) public onlyOwner{
        require(totalPercentage + _ownershipPercentage <=100,"Total Ownership max 100%");
        Artist memory newArtist = Artist(_artistAddress, _ownershipPercentage);
        artists.push(newArtist);
        artistToOwnershipPercentage[_artistAddress] = _ownershipPercentage;
        artistSigned[_artistAddress] = true;
        totalPercentage += _ownershipPercentage;
    }

    // base func milestone
    function addMilestone(string memory _description, uint256 _deadline) public onlyOwner{
        milestones.push(Milestone(_description,_deadline,false));
    }

    function markMilestoneAsCompleted(uint256 _index) public onlyOwner{
        Milestone storage milestone = milestones[_index];
        milestone.completed = true;
        emit MilestoneCompleted(_index, milestone.description);
    }

    // base func sign
    function signContract(bytes calldata _signature) public{
        require(artistToOwnershipPercentage[msg.sender] > 0 , "must be an artist of the project");
        bytes32 hash = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("CollaboritiveArt(address artist)"),
            msg.sender
        )));
        address signer = ECDSA.recover(hash, _signature);
        require(signer == msg.sender, "invalid signature");
        artistSigned[msg.sender] = true;
        emit ArtistSigned(msg.sender);
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