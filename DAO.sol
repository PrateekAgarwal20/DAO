pragma solidity ^0.4.8;

contract DAO{
    uint256 tokenCost;
    uint256 tokenSellLength;
    uint256 start;
    DAOToken daoToken;
    uint256 votingLength;
    mapping(uint => Proposal) proposalsID;

    uint[] proposals;

    struct Proposal{
        uint256 startTime;
        address recipient;
        uint256 amount;
        string description;
        uint256 amountROI;
        mapping (address => VotingInfo) votingInfo;
        uint256 numVotesFor;
        uint256 numVoted;
    }

    struct VotingInfo{
        bool voted;
        bool vote;
    }

    modifier isTokenHolder{
        if (daoToken.balanceOf(msg.sender) == 0) throw;
        _;
    }

    modifier noLiveProposals{
        uint256 propStartTime = proposalsID[proposals[proposals.length-1]].startTime;
        if( propStartTime != 0 &&
            now <= (propStartTime + votingLength)) throw;
        _;
    }

    function DAO (uint256 _tokenCost, uint256 _tokenSellLength, uint256 _votingLength){
        start = now;
        tokenCost = _tokenCost;
        tokenSellLength = _tokenSellLength;
        votingLength = _votingLength;

        // The totalSupply is 0 until no more tokens can be sold.
        daoToken = new DAOToken(0, this);
    }

    function invest() payable returns (bool success) {
        if(now > (start + tokenSellLength)) return false;
        uint256 numTokens = msg.value/tokenCost;
        daoToken.addTokens(msg.sender, numTokens);
        return true;
    }

    // this function has two modifiers. Together, they make sure only token
    // holders can call this function when there are no live proposals. This means
    // there cannot be more than 1 live proposal at a time. When this function
    // is called, it creates a new proposal, adds the appropriate information
    // to the proposals mapping, then sets the liveProposal to the proposal
    // that was just created.
    function newProposal(address _recipient, uint _amount, string _description, uint _amountROI) isTokenHolder noLiveProposals returns (uint256 _proposalID) {
        uint256 proposalID = (uint256)(sha3(_recipient, _amount, _description, _amountROI));
        Proposal memory currProp = Proposal(now, _recipient, _amount, _description, _amountROI, 0, 0);
        proposalsID[proposalID] = currProp;

        proposals.push(proposalID);

        return proposalID;
    }

    // This function allows token holders to vote.
    function vote(uint _proposalID, bool _supportProposal) isTokenHolder {
        Proposal proposal = proposalsID[_proposalID];
        if(now > (proposal.startTime + votingLength)) throw;

        if(proposal.votingInfo[msg.sender].voted){
            if(proposal.votingInfo[msg.sender].vote && !_supportProposal){
                proposal.numVotesFor--;
            } else if(proposal.votingInfo[msg.sender].vote && _supportProposal){
                proposal.numVotesFor++;
            }
        } else {
            if (_supportProposal) proposal.numVotesFor++;
            proposal.numVoted++;
            proposal.votingInfo[msg.sender].vote = _supportProposal;
            proposal.votingInfo[msg.sender].voted = true;
        }
    }

    function executeProposal(uint _proposalId) returns (bool success) {
        Proposal currProp = proposalsID[_proposalId];
        if(now < (currProp.startTime + votingLength)) return false;
        if(currProp.numVotesFor >= currProp.numVoted/2) {
            daoToken.approve(currProp.recipient, currProp.amount);
            return true;
        }
        return false;
    }

    function transfer(address _to, uint _value) noLiveProposals returns (bool){
        return daoToken.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) noLiveProposals returns (bool success){
          daoToken.transferFrom(_from, _to, _value);
    }

    // Can approve while there are live proposals, but cannot actually withdraw.
    // In other words, the transaction can be allowed but not carried out.
    function approve(address _spender, uint _value) returns (bool){
        return daoToken.approve(_spender, _value);
    }

    function balanceOf(address _owner) constant returns (uint256 balance){
        return daoToken.balanceOf(_owner);
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return daoToken.allowance(_owner, _spender);
    }

    function payBackInvestment(uint _proposalId) returns (bool success){
        // Little confused as to what this is supposed to do/ under what series of
        // events this would be called under.
        // Is this saying that the recipient of the ROI from a proposal
        // can pay their ROI back? Confused.
    }

    function withdrawEther() noLiveProposals returns (bool){
        // Also this one. They take all the ether from their DAO Tokens
        // using the exchange rate, sure, but what is meant by the portion of
        // ROI?
    }


}







contract DAOToken {
    uint256 public totalSupply;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) approvals;
    address private DAOAddress;
    uint256 public numTokenHolders = 0;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function DAOToken(uint256 _totalSupply, address _DAOAddress){
        totalSupply = _totalSupply;
        DAOAddress = _DAOAddress;
    }

    modifier isDAO{
        if(msg.sender != DAOAddress) throw;
        _;
    }

    function numTokenHolders() constant returns (uint256 numTokenHolders){
        return numTokenHolders;
    }

    function totalSupply() constant returns (uint256 totalSupply){
        return totalSupply;
    }

    function balanceOf(address _owner) constant returns (uint256 balance){
        return balanceOf[_owner];
    }

    function transfer(address _to, uint256 _value) isDAO returns (bool success){
        if(balanceOf[msg.sender] < _value) return false;
        if(balanceOf[_to] == 0) numTokenHolders++;

        balanceOf[_to] += _value;
        balanceOf[msg.sender] -= _value;

        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) isDAO returns (bool success){
        if(balanceOf[msg.sender] < _value) return false;
        if(approvals[_from][msg.sender] < _value) return false;
        if(balanceOf[_to] == 0) numTokenHolders++;

        balanceOf[_to] += _value;
        balanceOf[_from] -= _value;
        approvals[_from][msg.sender] -= _value;

        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) isDAO returns (bool success){
        if(balanceOf[msg.sender] < _value) return false;

        approvals[msg.sender][_spender] += _value;

        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return approvals[_owner][msg.sender];
    }

    function addTokens(address _owner, uint256 _amount) isDAO {
        totalSupply += _amount;
        if(balanceOf[_owner] == 0) numTokenHolders++;
        balanceOf[_owner] += _amount;
    }
}
