/* emacs buffer mode hint -*- objc -*- */
/*
 * libical 3 / libical 4 compatibility, included by config.h after the
 * libical header.
 *
 * The sources use the libical 4 names for the functions libical 4 only
 * renamed : this file defines them on top of libical 3.
 *
 * Recurrence rules changed more : libical 3 passes struct
 * icalrecurrencetype by value, with a rscale string owned by whoever
 * made the rule, libical 4 passes reference counted pointers and stores
 * the BY parts as arrays with a size. The sa_recur_* functions hide
 * that : a rule is always a struct icalrecurrencetype *, owned by the
 * caller, which frees it with sa_recur_free().
 */

#ifndef _ICALCOMPAT_H_
#define _ICALCOMPAT_H_

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#if defined(ICAL_MAJOR_VERSION) && ICAL_MAJOR_VERSION >= 4
#define SA_LIBICAL4
#else
#undef SA_LIBICAL4
#endif

#ifdef SA_LIBICAL4

static inline struct icalrecurrencetype *sa_recur_new(void)
{
  return icalrecurrencetype_new();
}
/* A copy of r, NULL if r is NULL */
static inline struct icalrecurrencetype *sa_recur_copy(const struct icalrecurrencetype *r)
{
  return r ? icalrecurrencetype_clone((struct icalrecurrencetype *)r) : NULL;
}
static inline void sa_recur_free(struct icalrecurrencetype *r)
{
  if (r)
    icalrecurrencetype_unref(r);
}
/* NULL if str isn't a valid rule */
static inline struct icalrecurrencetype *sa_recur_from_string(const char *str)
{
  return icalrecurrencetype_new_from_string(str);
}
/* A copy of the rule of a RRULE property */
static inline struct icalrecurrencetype *sa_recur_from_property(icalproperty *prop)
{
  return sa_recur_copy(icalproperty_get_rrule(prop));
}
static inline icalproperty *sa_recur_new_property(const struct icalrecurrencetype *r)
{
  return icalproperty_new_rrule((struct icalrecurrencetype *)r);
}
/*
 * The iterator may use r : it must outlive the iterator.
 *
 * libical 4 (4.0.9) gives up looking for the next occurrence after
 * ICAL_LIMIT_RECURRENCE_SEARCH candidates, and then returns the last
 * candidate although it doesn't match the rule : FREQ=YEARLY;BYDAY=MO;
 * BYSETPOS=54 gives mondays in 3940, 5857... and FREQ=DAILY;BYMONTH=2;
 * BYMONTHDAY=31 gives 2297-10-17 (100000 days after DTSTART). Do as
 * libical 3 : no limit, but stop at the end of 2582, libical 3's last
 * year (and libical 4's without ICU, which looks up to the year 20000).
 * A rule that never matches has no occurrence again
 */
static inline icalrecur_iterator *sa_recur_iterator_new(const struct icalrecurrencetype *r,
							struct icaltimetype dtstart)
{
  icalrecur_iterator *it;

  icallimit_set(ICAL_LIMIT_RECURRENCE_SEARCH, SIZE_MAX);
  it = icalrecur_iterator_new((struct icalrecurrencetype *)r, dtstart);
  if (it)
    icalrecur_iterator_set_end(it, icaltime_from_day_of_year(1, 2583));
  return it;
}
/* Number of values of a BY part (ICAL_BY_DAY...) and the i-th value */
static inline int sa_recur_by_count(const struct icalrecurrencetype *r, icalrecurrencetype_byrule part)
{
  return r->by[part].size;
}
static inline short sa_recur_by_value(const struct icalrecurrencetype *r, icalrecurrencetype_byrule part, int i)
{
  return r->by[part].data[i];
}

#else /* libical 3 */

static inline struct icaldurationtype icaldurationtype_from_seconds(int seconds)
{
  return icaldurationtype_from_int(seconds);
}
/* Days count 24 hours, like libical 4's function */
static inline int icaldurationtype_as_utc_seconds(struct icaldurationtype duration)
{
  return icaldurationtype_as_int(duration);
}
static inline struct icaltimetype icalduration_extend(struct icaltimetype t, struct icaldurationtype d)
{
  return icaltime_add(t, d);
}
static inline struct icaldurationtype icalduration_from_times(struct icaltimetype t1, struct icaltimetype t2)
{
  return icaltime_subtract(t1, t2);
}
static inline icalcomponent *icalcomponent_clone(const icalcomponent *c)
{
  return icalcomponent_new_clone((icalcomponent *)c);
}

/* libical 4's BY parts */
typedef enum
{
  ICAL_BY_MONTH = 0,
  ICAL_BY_WEEK_NO,
  ICAL_BY_YEAR_DAY,
  ICAL_BY_MONTH_DAY,
  ICAL_BY_DAY,
  ICAL_BY_HOUR,
  ICAL_BY_MINUTE,
  ICAL_BY_SECOND,
  ICAL_BY_SET_POS,
  ICAL_BY_NUM_PARTS
} icalrecurrencetype_byrule;

static inline struct icalrecurrencetype *sa_recur_new(void)
{
  struct icalrecurrencetype *r = malloc(sizeof(*r));

  if (r)
    icalrecurrencetype_clear(r);
  return r;
}
/* Takes ownership of value.rscale */
static inline struct icalrecurrencetype *sa_recur_wrap(struct icalrecurrencetype value)
{
  struct icalrecurrencetype *r = malloc(sizeof(*r));

  if (r)
    *r = value;
  else
    free(value.rscale);
  return r;
}
static inline struct icalrecurrencetype *sa_recur_copy(const struct icalrecurrencetype *r)
{
  struct icalrecurrencetype value;

  if (!r)
    return NULL;
  value = *r;
  if (r->rscale)
    value.rscale = strdup(r->rscale);
  return sa_recur_wrap(value);
}
static inline void sa_recur_free(struct icalrecurrencetype *r)
{
  if (r) {
    free(r->rscale);
    free(r);
  }
}
/* libical 3 returns an empty rule for an invalid string : NULL, like libical 4 */
static inline struct icalrecurrencetype *sa_recur_from_string(const char *str)
{
  struct icalrecurrencetype value = icalrecurrencetype_from_string(str);

  if (value.freq == ICAL_NO_RECURRENCE) {
    free(value.rscale);
    return NULL;
  }
  /* icalrecurrencetype_from_string() allocates rscale */
  return sa_recur_wrap(value);
}
static inline struct icalrecurrencetype *sa_recur_from_property(icalproperty *prop)
{
  /* The rscale of the returned rule belongs to the property */
  struct icalrecurrencetype value = icalproperty_get_rrule(prop);

  return sa_recur_copy(&value);
}
static inline icalproperty *sa_recur_new_property(const struct icalrecurrencetype *r)
{
  return icalproperty_new_rrule(*r);
}
/* The iterator keeps a copy of r, rscale pointer included : r must outlive it */
static inline icalrecur_iterator *sa_recur_iterator_new(const struct icalrecurrencetype *r,
							struct icaltimetype dtstart)
{
  return icalrecur_iterator_new(*r, dtstart);
}
static inline const short *sa_recur_by_array(const struct icalrecurrencetype *r,
					     icalrecurrencetype_byrule part, int *size)
{
  switch (part) {
  case ICAL_BY_MONTH: *size = ICAL_BY_MONTH_SIZE; return r->by_month;
  case ICAL_BY_WEEK_NO: *size = ICAL_BY_WEEKNO_SIZE; return r->by_week_no;
  case ICAL_BY_YEAR_DAY: *size = ICAL_BY_YEARDAY_SIZE; return r->by_year_day;
  case ICAL_BY_MONTH_DAY: *size = ICAL_BY_MONTHDAY_SIZE; return r->by_month_day;
  case ICAL_BY_DAY: *size = ICAL_BY_DAY_SIZE; return r->by_day;
  case ICAL_BY_HOUR: *size = ICAL_BY_HOUR_SIZE; return r->by_hour;
  case ICAL_BY_MINUTE: *size = ICAL_BY_MINUTE_SIZE; return r->by_minute;
  case ICAL_BY_SECOND: *size = ICAL_BY_SECOND_SIZE; return r->by_second;
  case ICAL_BY_SET_POS: *size = ICAL_BY_SETPOS_SIZE; return r->by_set_pos;
  default: *size = 0; return NULL;
  }
}
/* libical 3 ends the BY arrays with ICAL_RECURRENCE_ARRAY_MAX */
static inline int sa_recur_by_count(const struct icalrecurrencetype *r, icalrecurrencetype_byrule part)
{
  int size;
  const short *array = sa_recur_by_array(r, part, &size);
  int n = 0;

  while (n < size && array[n] != ICAL_RECURRENCE_ARRAY_MAX)
    n++;
  return n;
}
static inline short sa_recur_by_value(const struct icalrecurrencetype *r, icalrecurrencetype_byrule part, int i)
{
  int size;

  return sa_recur_by_array(r, part, &size)[i];
}

#endif

#endif
