package com.hostk8s.worker.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;

@Entity
@Table(name = "votes")
public class Vote {

    @Id
    @Column(name = "id")
    private String voterId;

    @NotNull
    @Column(name = "vote")
    private String vote;

    // Default constructor
    public Vote() {}

    // Constructor
    public Vote(String voterId, String vote) {
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
        return "Vote{" +
                "voterId='" + voterId + '\'' +
                ", vote='" + vote + '\'' +
                '}';
    }
}
