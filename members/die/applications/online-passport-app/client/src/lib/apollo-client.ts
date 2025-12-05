import { ApolloClient, InMemoryCache, HttpLink } from "@apollo/client";

const apiUrl = import.meta.env.VITE_API_URL || "http://localhost:3000/api";

const client = new ApolloClient({
  link: new HttpLink({
    uri: `${apiUrl}/graphql`
  }),
  cache: new InMemoryCache(),
});

export default client;