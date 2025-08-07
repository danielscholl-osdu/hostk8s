package com.hostk8s.worker.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class VoteMessage {

    @JsonProperty("voter_id")
    private String voterId;

    @JsonProperty("vote")
    private String vote;

    // Default constructor
    public VoteMessage() {}

    // Constructor
    public VoteMessage(String voterId, String vote) {
        this.voterId = voterId;
        this.vote = vote;
    }

    // Getters and Setters
    public String getVoterId() {
        return voterId;
    }

    public void setVoterId(String voterId) {
        this.voterId = voterId;
    }

    public String getVote() {
        return vote;
    }

    public void setVote(String vote) {
        this.vote = vote;
    }

    @Override
    public String toString() {
        return "VoteMessage{" +
                "voterId='" + voterId + '\'' +
                ", vote='" + vote + '\'' +
                '}';
    }
}
