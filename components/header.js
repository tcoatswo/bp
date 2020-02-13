import Link from "next/link";

/**
 * @name Header
 * @prop {Object} user - logged in user
 * @prop {Boolean} loading - if the site is loading
 */
export const Header = ({ user, loading }) => (
  <header>
    <nav>
      <ul>
        <li>
          <input type="text" placeholder="Search" />
        </li>
        <li>
          <a href="https://github.com/bionicles/bp/issues/new">Feedback</a>
        </li>
        <li>
          <a href="mailto:bion@bitpharma.com">Contact</a>
        </li>
        {!loading &&
          (user ? (
            <li>
              <Link href="/me">
                <a>Me</a>
              </Link>
            </li>
          ) : (
            <li>
              <a href="/auth">Auth</a>
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
