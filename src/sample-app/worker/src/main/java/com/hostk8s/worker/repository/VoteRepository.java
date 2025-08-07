package com.hostk8s.worker.repository;

import com.hostk8s.worker.model.Vote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface VoteRepository extends JpaRepository<Vote, String> {

    // Spring Data JPA automatically provides:
    // - save() for insert/update votes
    // - findById() for retrieving by voter ID
    // - Custom queries can be added here if needed

}
