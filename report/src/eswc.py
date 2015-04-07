class Eswc():

    def add_arguments(self, parser):
        """Parse command line arguments"""

        parser.description = "Load eswc data"
        parser.add_argument('file', metavar='eswc_training_file', type=str, help='The training file')

    def load(self, args):
        """Load users and products."""

        products = {}
        users = {}

        # Each line is composed by: userID \t itemID
        with open(args.file) as f:
            for line in f:
                s = line.rstrip().split('\t')
                user_id, product_id = s[0], s[1]

                if not product_id in products:
                    products[product_id] = Product(product_id)

                if not user_id in users:
                    users[user_id] = User(user_id)

                users[user_id].add_history(product_id, 1)

        return users, products

