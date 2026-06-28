'use client';
import { Component, ReactNode } from 'react';

export class ErrorCatcher extends Component<
  { children: ReactNode },
  { err: any }
> {
  state = { err: null as any };
  static getDerivedStateFromError(err: any) {
    return { err };
  }
  render() {
    if (this.state.err) {
      const e = this.state.err;
      return (
        <pre
          style={{
            color: '#fff',
            background: '#111',
            padding: 20,
            whiteSpace: 'pre-wrap',
            fontSize: 12,
          }}
        >
          {'PREVIEW_ERR\n' +
            (e?.message || String(e)) +
            '\n---\n' +
            (e?.stack || '')}
        </pre>
      );
    }
    return this.props.children as any;
  }
}
