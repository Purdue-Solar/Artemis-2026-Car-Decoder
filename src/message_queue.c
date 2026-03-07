/* Authors: Nanson Chen */
/* Created on: 3/7/2026 */
/* Message queue implementation - circular queue for struct message */

#include "message_queue.h"
#include <stdlib.h>
#include <string.h>

/*
 * Function: message_queue_init
 * Initialize a message queue with specified capacity.
 */

int message_queue_init(struct message_queue *queue, size_t capacity) {
  if (queue == NULL || capacity == 0) {
    return -1;
  }

  queue->buffer = (struct message *)calloc(capacity, sizeof(struct message));
  if (queue->buffer == NULL) {
    return -1;
  }

  queue->capacity = capacity;
  queue->size = 0;
  queue->head = 0;
  queue->tail = 0;

  return 0;
}

/*
 * Function: message_queue_destroy
 * Free resources associated with the queue.
 */

void message_queue_destroy(struct message_queue *queue) {
  if (queue == NULL) {
    return;
  }

  if (queue->buffer != NULL) {
    free(queue->buffer);
    queue->buffer = NULL;
  }

  queue->capacity = 0;
  queue->size = 0;
  queue->head = 0;
  queue->tail = 0;
}

/*
 * Function: message_queue_enqueue
 * Add a message to the back of the queue.
 */

int message_queue_enqueue(struct message_queue *queue,
                          const struct message *msg) {
  if (queue == NULL || msg == NULL) {
    return -1;
  }

  if (message_queue_is_full(queue)) {
    return -1;
  }

  /* Copy message to the tail position */
  memcpy(&queue->buffer[queue->tail], msg, sizeof(struct message));

  /* Update tail and size */
  queue->tail = (queue->tail + 1) % queue->capacity;
  queue->size++;

  return 0;
}

/*
 * Function: message_queue_dequeue
 * Remove and return the message from the front of the queue.
 */

int message_queue_dequeue(struct message_queue *queue, struct message *msg) {
  if (queue == NULL || msg == NULL) {
    return -1;
  }

  if (message_queue_is_empty(queue)) {
    return -1;
  }

  /* Copy message from the head position */
  memcpy(msg, &queue->buffer[queue->head], sizeof(struct message));

  /* Update head and size */
  queue->head = (queue->head + 1) % queue->capacity;
  queue->size--;

  return 0;
}

/*
 * Function: message_queue_peek
 * View the message at the front of the queue without removing it.
 */

int message_queue_peek(const struct message_queue *queue, struct message *msg) {
  if (queue == NULL || msg == NULL) {
    return -1;
  }

  if (message_queue_is_empty(queue)) {
    return -1;
  }

  /* Copy message from the head position */
  memcpy(msg, &queue->buffer[queue->head], sizeof(struct message));

  return 0;
}

/*
 * Function: message_queue_is_empty
 * Check if the queue is empty.
 */

bool message_queue_is_empty(const struct message_queue *queue) {
  if (queue == NULL) {
    return true;
  }

  return (queue->size == 0);
}

/*
 * Function: message_queue_is_full
 * Check if the queue is full.
 */

bool message_queue_is_full(const struct message_queue *queue) {
  if (queue == NULL) {
    return true;
  }

  return (queue->size == queue->capacity);
}

/*
 * Function: message_queue_size
 * Get the current number of messages in the queue.
 */

size_t message_queue_size(const struct message_queue *queue) {
  if (queue == NULL) {
    return 0;
  }

  return queue->size;
}

/*
 * Function: message_queue_capacity
 * Get the maximum capacity of the queue.
 */

size_t message_queue_capacity(const struct message_queue *queue) {
  if (queue == NULL) {
    return 0;
  }

  return queue->capacity;
}

/*
 * Function: message_queue_clear
 * Remove all messages from the queue.
 */

void message_queue_clear(struct message_queue *queue) {
  if (queue == NULL) {
    return;
  }

  queue->size = 0;
  queue->head = 0;
  queue->tail = 0;

  /* Optional: zero out the buffer */
  if (queue->buffer != NULL && queue->capacity > 0) {
    memset(queue->buffer, 0, queue->capacity * sizeof(struct message));
  }
}
