import Link from "next/link";

/**
 * @name Header
 * @prop {object} user - logged in user
 * @prop {boolean} loading - if the site is loading
 * @example
 * ```jsx
 * const props = { user, loading };
 * return <Header {...props} />
 * ```
 */
export const Header = ({ user, loading }) => (
  <header>
    <nav>
      <ul>
        <li>
          <input type="text" placeholder="Search" />
        </li>
        <li>
          <a href="https://github.com/bionicles/bp/issues/new" target="_blank">
            Feedback
          </a>
        </li>
        <li>
          <a href="/docs/index.html" target="_blank">
            Docs
          </a>
        </li>
        <li>
          <a href="mailto:bion@bitpharma.com">Contact</a>
        </li>
        {!loading &&
          (user ? (
            <li>
              <Link href="/me">
                <a>{user.displayName}</a>
              </Link>
            </li>
          ) : (
            <li>
              <a href="/auth">Log In</a>
            </li>
          ))}
      </ul>
    </nav>

    <style jsx>{`
      header {
        padding: 0.2rem;
        color: #fff;
        background-color: #333;
      }
      nav {
        max-width: 42rem;
        margin: 1.5rem auto;
      }
      ul {
        display: flex;
        list-style: none;
        margin-left: 0;
        padding-left: 0;
      }
      li {
        margin-right: 1rem;
      }
      li:nth-child(2) {
        margin-right: auto;
      }
      a {
        color: #fff;
        text-decoration: none;
      }
      button {
        font-size: 1rem;
        color: #fff;
        cursor: pointer;
        border: none;
        background: none;
      }
    `}</style>
  </header>
);
