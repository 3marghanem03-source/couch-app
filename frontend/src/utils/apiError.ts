import axios from 'axios';

export function getApiErrorMessage(err: unknown, fallback = 'Something went wrong') {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data as any;
    const msg = typeof data?.error === 'string' ? data.error : undefined;
    if (msg) return msg;

    // Axios default message is often unhelpful ("Request failed with status code 409")
    if (err.response?.status) {
      return `Request failed (${err.response.status}).`;
    }
  }

  if (err instanceof Error && err.message) return err.message;
  return fallback;
}
