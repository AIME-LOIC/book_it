const TIME_ZONE = 'Africa/Kigali';

const dateFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

const timeFormatter = new Intl.DateTimeFormat('en-GB', {
  timeZone: TIME_ZONE,
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

export const getRwandaDateKey = (date = new Date()) => dateFormatter.format(date);

export const getRwandaTimeParts = (date = new Date()) => {
  const parts = Object.fromEntries(
    timeFormatter.formatToParts(date)
      .filter((part) => part.type !== 'literal')
      .map(({ type, value }) => [type, Number(value)]),
  );
  return { hour: parts.hour, minute: parts.minute };
};

export const getRwandaMinutesOfDay = (date = new Date()) => {
  const { hour, minute } = getRwandaTimeParts(date);
  return hour * 60 + minute;
};
