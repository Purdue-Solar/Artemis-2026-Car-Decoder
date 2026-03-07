/* Authors: Nanson Chen */
/* Created on: 3/7/2026 */
/* Message queue interface - circular queue for struct message */

#ifndef MESSAGE_QUEUE_H
#define MESSAGE_QUEUE_H

#include "decoder.h"
#include <stdbool.h>
#include <stddef.h>

/* Queue structure using a circular buffer */
struct message_queue {
  struct message *buffer; /* Dynamic array of messages */
  size_t capacity;        /* Maximum number of messages */
  size_t size;            /* Current number of messages */
  size_t head;            /* Index of the front element */
  size_t tail;            /* Index where next element will be added */
};

/*
 * Function: message_queue_init
 * Initialize a message queue with specified capacity.
 *
 * Parameters:
 *   queue    - Pointer to the queue structure
 *   capacity - Maximum number of messages the queue can hold
 *
 * Returns: 0 on success, -1 on failure (allocation error)
 */
int message_queue_init(struct message_queue *queue, size_t capacity);

/*
 * Function: message_queue_destroy
 * Free resources associated with the queue.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 */
void message_queue_destroy(struct message_queue *queue);

/*
 * Function: message_queue_enqueue
 * Add a message to the back of the queue.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 *   msg   - Pointer to the message to add
 *
 * Returns: 0 on success, -1 if queue is full
 */
int message_queue_enqueue(struct message_queue *queue,
                          const struct message *msg);

/*
 * Function: message_queue_dequeue
 * Remove and return the message from the front of the queue.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 *   msg   - Pointer to store the dequeued message
 *
 * Returns: 0 on success, -1 if queue is empty
 */
int message_queue_dequeue(struct message_queue *queue, struct message *msg);

/*
 * Function: message_queue_peek
 * View the message at the front of the queue without removing it.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 *   msg   - Pointer to store the peeked message
 *
 * Returns: 0 on success, -1 if queue is empty
 */
int message_queue_peek(const struct message_queue *queue, struct message *msg);

/*
 * Function: message_queue_is_empty
 * Check if the queue is empty.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 *
 * Returns: true if empty, false otherwise
 */
bool message_queue_is_empty(const struct message_queue *queue);

/*
 * Function: message_queue_is_full
 * Check if the queue is full.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 *
 * Returns: true if full, false otherwise
 */
bool message_queue_is_full(const struct message_queue *queue);

/*
 * Function: message_queue_size
 * Get the current number of messages in the queue.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 *
 * Returns: Number of messages currently in the queue
 */
size_t message_queue_size(const struct message_queue *queue);

/*
 * Function: message_queue_capacity
 * Get the maximum capacity of the queue.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 *
 * Returns: Maximum capacity of the queue
 */
size_t message_queue_capacity(const struct message_queue *queue);

/*
 * Function: message_queue_clear
 * Remove all messages from the queue.
 *
 * Parameters:
 *   queue - Pointer to the queue structure
 */
void message_queue_clear(struct message_queue *queue);

#endif /* MESSAGE_QUEUE_H */
