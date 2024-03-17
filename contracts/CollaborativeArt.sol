// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// project : develop
contract CollaborativeArt is ERC721URIStorage, Ownable, ReentrancyGuard{
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;
    
    struct Artist{
        address artistAddress;
        uint256 ownershipPercentage;
        bool hasSigned;
    }

    struct Milestone{
        string description;
        uint256 deadline;
        bool completed;
        uint256 budget;
    }
    struct Phase{
        string phaseName;
        Milestone[] milestones;
        uint256 totalBudget;
    }
    // test dispute
    struct Dispute{
        string description;
        EnumerableSet.AddressSet voters;
        uint256 affirmativeVotes;
        bool resolved;
        bool decision;
    }

    // dispute global
    EnumerableSet.AddressSet private artists;
    mapping(address => Artist) public artistDetails;
    Counters.Counter private _tokenIds;
    Counters.Counter private _disputeIds;
    mapping(uint256 => Dispute) public disputes;

    address public owner;
    // Artist[] public artists;
    Phase[] public phases;

    mapping(address => uint256) private artistToOwnershipPercentage;
    mapping(address => bool) private artistSigned;
    uint256 public totalOwnershipPercentage = 0;
    uint256 public artworkPrice;
    IERC20 public paymentToken;

    event ArtistAdded(address indexed artist, uint256 ownershipPercentage);
    // dispute event
    event DisputeCreated(uint256 indexed disputeId, string description);
    event DisputeVoted(uint256 indexed disputeId, address indexed voter, bool vote);
    event DisputeResolved(uint256 indexed disputeId, bool decision);
    event PhaseAdded(string phaseName);
    event MilestoneCompleted(uint256 phaseIndex, uint256 milestoneIndex,string description);
    event ArtworkSold(uint256 price, string message);
    event DisputeResolved(string message);
    event ArtistSigned(address indexed artist);
    event ArtworkMinted(address indexed owner, uint256 indexed tokenId, string tokenURI);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier onlyArtist() {
        require(artistSigned[msg.sender], "Only an artist can call this function");
        _;
    }

    constructor(address _paymentToken) EIP712("CollaborativeArt","1.0"){
        owner = msg.sender;
        paymentToken = IERC20(_paymentToken);
    }

    // function add artist : 
    function addArtist(address _artistAddress, uint256 _ownershipPercentage) public onlyOwner{
        require(totalOwnershipPercentage + _ownershipPercentage <=100,"Total Ownership max 100%");
        Artist memory newArtist = Artist(_artistAddress, _ownershipPercentage);
        artists.push(newArtist);
        artistToOwnershipPercentage[_artistAddress] = _ownershipPercentage;
        artistSigned[_artistAddress] = true;
        totalOwnershipPercentage += _ownershipPercentage;
    }

    // function milestone :
    function addPhase(string memory _phaseName) public onlyOwner{
        phases.push(Phase(_phaseName,new Milestone,0));
        emit PhaseAdded(_phaseName);
    }

    function addMilestoneToPhase(uint256 _phaseIndex, uint256 _milestoneIndex) public onlyOwner{
        Phase storage phase = phases[_phaseIndex];
        Milestone storage milestone = phase.milestones[_milestoneIndex];
        milestone.completed = true;
        emit MilestoneCompleted(_phaseIndex, _milestoneIndex, milestone.description);
    }

    function markMilestoneAsCompleted(uint256 _phaseIndex, uint256 _milestoneIndex) public onlyOwner{
        Phase storage phase = phases[_phaseIndex];
        Milestone storage milestone = phase.milestones[_milestoneIndex];
        milestone.completed = true;
        emit MilestoneCompleted(_phaseIndex, _milestoneIndex, milestone.description);
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
        distributeFunds(msg.value);
        emit ArtworkSold(artworkPrice, "artwork sold");
    }

    // base func pay
    function distributeFunds(uint256 _amount) public onlyOwner nonReentrant {
        require(paymentToken.transferFrom(msg.sender,address(this), _amount),"Payment tx failed");
        for (uint256 i = 0; i < artists.length; i++){
            Artist memory artist = artists[i];
            if(artistSigned[artist.artistAddress]){
                uint256 payment = (_amount * artist.ownershipPercentage)/100;
                // payable(artist.artistAddress).transfer((artworkPrice * artist.ownershipPercentage )/100);
                require(paymentToken.transfer(artist.artistAddress,payment),"Payment to artist failed");
            }
        }
    }

    // base func dispute
    function resolveDispute(string memory _message) public view onlyOwner returns (string memory) {
        return _message;
    }
}