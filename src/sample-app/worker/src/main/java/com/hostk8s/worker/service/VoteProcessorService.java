package com.hostk8s.worker.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hostk8s.worker.dto.VoteMessage;
import com.hostk8s.worker.model.Vote;
import com.hostk8s.worker.repository.VoteRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class VoteProcessorService {

    private static final Logger logger = LoggerFactory.getLogger(VoteProcessorService.class);
    private static final String REDIS_VOTES_KEY = "votes";

    @Autowired
    private RedisTemplate<String, String> redisTemplate;

    @Autowired
    private VoteRepository voteRepository;

    @Autowired
    private ObjectMapper objectMapper;

    private long processedCount = 0;

    @Scheduled(fixedDelay = 100) // Process every 100ms
    public void processVotes() {
        try {
            // Pop vote from Redis queue (left pop for FIFO)
            String voteJson = redisTemplate.opsForList().leftPop(REDIS_VOTES_KEY);

            if (voteJson != null) {
                processVote(voteJson);
            }

        } catch (Exception e) {
            logger.error("Error processing votes from Redis: {}", e.getMessage(), e);
        }
    }

    private void processVote(String voteJson) {
        try {
            // Parse JSON message
            VoteMessage voteMessage = objectMapper.readValue(voteJson, VoteMessage.class);
            processedCount++;

            logger.info("Processing vote #{} for '{}' by '{}'",
                       processedCount, voteMessage.getVote(), voteMessage.getVoterId());

            // Create or update vote in database
            Vote vote = new Vote(voteMessage.getVoterId(), voteMessage.getVote());
            voteRepository.save(vote);

            logger.debug("Vote persisted successfully: {}", vote);

        } catch (JsonProcessingException e) {
            logger.error("Failed to parse vote JSON: {}", voteJson, e);
        } catch (Exception e) {
            logger.error("Failed to persist vote: {}", voteJson, e);
        }
    }

    public long getProcessedCount() {
        return processedCount;
    }
}
