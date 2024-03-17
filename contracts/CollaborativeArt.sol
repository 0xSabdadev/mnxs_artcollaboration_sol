// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// project : develop
contract CollaborativeArt is EIP712, ReentrancyGuard{
    struct Artist{
        address artistAddress;
        uint256 ownershipPercentage;
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

    address public owner;
    Artist[] public artists;
    Phase[] public phases;

    mapping(address => uint256) private artistToOwnershipPercentage;
    mapping(address => bool) private artistSigned;
    uint256 public totalOwnershipPercentage = 0;
    // uint256 public artworkPrice;
    IERC20 public paymentToken;

    event PhaseAdded(string phaseName);
    event MilestoneCompleted(uint256 phaseIndex, uint256 milestoneIndex,string description);
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

    constructor(address _paymentToken) EIP712("CollaborativeArt","1.0"){
        owner = msg.sender;
        paymentToken = IERC20(_paymentToken);
    }

    // base function add
    function addArtist(address _artistAddress, uint256 _ownershipPercentage) public onlyOwner{
        require(totalOwnershipPercentage + _ownershipPercentage <=100,"Total Ownership max 100%");
        Artist memory newArtist = Artist(_artistAddress, _ownershipPercentage);
        artists.push(newArtist);
        artistToOwnershipPercentage[_artistAddress] = _ownershipPercentage;
        artistSigned[_artistAddress] = true;
        totalOwnershipPercentage += _ownershipPercentage;
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
            if(artistSigned[artist.artistAddress]){
                payable(artist.artistAddress).transfer((artworkPrice * artist.ownershipPercentage )/100);
            }
        }
    }

    // base func dispute
    function resolveDispute(string memory _message) public view onlyOwner returns (string memory) {
        return _message;
    }
}