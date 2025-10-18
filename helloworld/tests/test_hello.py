import unittest
from helloworld.app import app

class TestFlaskApp(unittest.TestCase):

    def setUp(self):
        self.client = app.test_client()

    def test_root(self):
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"Hello, World!", response.data)

    def test_greet(self):
        name = "Alice"
        response = self.client.get(f'/greet/{name}')
        self.assertEqual(response.status_code, 200)
        self.assertIn(f"Hello, {name}!".encode(), response.data)

if __name__ == '__main__':
    unittest.main()
