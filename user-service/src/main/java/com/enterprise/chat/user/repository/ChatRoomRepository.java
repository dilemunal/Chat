package com.enterprise.chat.user.repository;

import com.enterprise.chat.user.model.ChatRoom;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ChatRoomRepository extends JpaRepository<ChatRoom, String> {
    @Query("SELECT cr FROM ChatRoom cr JOIN cr.members m WHERE m = :username")
    List<ChatRoom> findByMembersContaining(@Param("username") String username);
}
