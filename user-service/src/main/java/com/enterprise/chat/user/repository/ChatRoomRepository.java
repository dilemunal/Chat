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

    @Query("SELECT DISTINCT cr FROM ChatRoom cr JOIN cr.members m1 WHERE m1 = :username AND (LOWER(cr.name) LIKE LOWER(CONCAT('%', :query, '%')) OR EXISTS (SELECT m2 FROM ChatRoom cr2 JOIN cr2.members m2 WHERE cr2.id = cr.id AND m2 != :username AND LOWER(m2) LIKE LOWER(CONCAT('%', :query, '%'))))")
    List<ChatRoom> searchRooms(@Param("username") String username, @Param("query") String query);
}
